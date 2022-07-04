pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/nft/ICollection.sol";
import "./interfaces/IRoot.sol";
import "./interfaces/IUpgradable.sol";
import "./utils/Gas.sol";
import "./utils/TransferCanselReason.sol";
import "./utils/TransferKind.sol";
import "./Domain.sol";

import "@broxus/contracts/contracts/utils/CheckPubKey.sol";
import "ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "ton-eth-bridge-token-contracts/contracts/interfaces/IAcceptTokensTransferCallback.sol";


contract Root is IRoot, IAcceptTokensTransferCallback, IUpgradable, Addressable, TransferUtils, CheckPubKey {

    event Confiscated(string name, address owner, string reason);
    event Reserved(string name, string reason);
    event DomainCodeUpgraded(uint16 newVersion);

    address public _dao;
    address public _collection;

    Config public _config;
    TvmCell public _domainCode;
    uint16 public _domainVersion;

    address public _wallet;
    uint128 public _balance;
    bool public _active;


    modifier onlyDao() {
        require(msg.sender == _dao, 69);
        _;
    }

    modifier onActive() {
        require(_active, 69);
        _;
    }

    modifier onlyDomain(string name) {
        address domain = _domainAddress(name);
        require(msg.sender == domain, 69);
        _;
    }


    constructor(address dao, address collection, Config config, TvmCell platformCode, TvmCell domainCode) public checkPubKey {
        tvm.accept();
        _root = address(this);
        _dao = dao;
        _collection = collection;
        _config = config;
        _platformCode = platformCode;
        _domainCode = domainCode;
        _domainVersion = 1;
        ITokenRoot(_config.token).deployWallet{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            callback: onWalletDeployed
        }({
            owner: address(this),
            deployWalletValue: Gas.DEPLOY_WALLET_VALUE
        });
    }

    function onWalletDeployed(address wallet) public override {
        require(msg.sender == _config.token && _wallet.value == 0, 69);
        _wallet = wallet;
    }


    function checkName(string name) public responsible override returns (bool correct) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _isCorrectName(name);
    }

    function expectedPrice(string name) public responsible override returns (uint128 price) {
        (price, /*needZeroAuction*/) = _calcPrice(name);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} price;
    }


    function onAcceptTokensTransfer(
        address /*tokenRoot*/,
        uint128 amount,
        address sender,
        address /*senderWallet*/,
        address /*remainingGasTo*/,
        TvmCell payload
    ) public override {
        require(msg.sender == _wallet, 69);
        _reserve();
        _balance += amount;
        if (!_active) {
            _returnToken(amount, sender, TransferCanselReason.IS_NOT_ACTIVE);
            return;
        }

        (TransferKind kind, TvmCell data) = abi.decode(payload, (TransferKind, TvmCell));
        if (kind == TransferKind.REGISTER) {
            if (msg.value < Gas.REGISTER_VALUE) {
                _returnToken(amount, sender, TransferCanselReason.LOW_MSG_VALUE);
                return;
            }
            string name = abi.decode(data, string);
            (DomainSetup setup, optional(TransferCanselReason) error) = _buildDomainSetup(name, amount, sender);
            if (error.hasValue()) {
                _returnToken(amount, sender, error.get());
                return;
            }
            _register(name, sender, setup);
            sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
        } else if (kind == TransferKind.PROLONG) {
            if (msg.value < Gas.PROLONG_VALUE) {
                _returnToken(amount, sender, TransferCanselReason.LOW_MSG_VALUE);
                return;
            }
            string name = abi.decode(data, string);
            address domain = _domainAddress(name);
            _upgradeDomain(domain, Gas.UPGRADE_DOMAIN_VALUE, MsgFlag.SENDER_PAYS_FEES);
            IDomain(domain).prolong{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false  // todo if domain not exists
            }(amount, sender);
        } else {
            _returnToken(amount, sender, TransferCanselReason.UNKNOWN_TYPE);
        }
    }

    function onDomainDeployRetry(string name, uint128 amount, address sender) public override onlyDomain(name) {
        _reserve();
        _returnToken(amount, sender, TransferCanselReason.ALREADY_EXIST);
    }

    function onProlongReturn(string name, uint128 returnAmount, address sender) public override onlyDomain(name) {
        _reserve();
        _returnToken(returnAmount, sender, TransferCanselReason.DURATION_OVERFLOW);
    }

    function resolve(string name) public responsible override returns (address domain) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _domainAddress(name);
    }

    function confiscate(string name, address owner, string reason) public override onlyDao {
        _reserve();
        emit Confiscated(name, owner, reason);
        address domain = _domainAddress(name);
        IDomain(domain).confiscate{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(owner);
    }

    function reserve(string[] names, bool ignoreNameCheck, string reason) public override onlyDao {
        _reserve();
        for (string name : names) {
            require(_isCorrectName(name) || ignoreNameCheck, 69);
            emit Reserved(name, reason);
            DomainSetup setup = DomainSetup({
                owner: address(this),
                price: 0,
                needZeroAuction: false,
                reserved: true,
                expireTime: 0,
                amount: 0
            });
            _register(name, _dao, setup);
        }
    }

//    function collect(uint128 amount, address staking) public override onlyDao {
//        // todo collect while exception in prolong (we must return some tokens):
//        // 1) use onProlong + dont call "collect" (auto send to dao)
//        // 2) leave as is (maybe return to dao instead of staking)
//        require(amount <= _balance, 69);
//        TvmCell payload = abi.encode(reason);
//        _transferToken(amount, staking, payload);
//    }

    function execute(Action[] actions) public override onlyDao {
        for (Action action : actions) {
            _execute(action);
        }
    }

    function activate() public override onlyDao cashBack {
        _active = true;
    }

    function deactivate() public override onlyDao cashBack {
        _active = false;
    }


    function _buildDomainSetup(string name, uint128 amount, address owner) private view returns (DomainSetup, optional(TransferCanselReason)) {
        DomainSetup empty;
        if (!_isCorrectName(name)) {
            return (empty, TransferCanselReason.INVALID_NAME);
        }
        (uint128 price, bool needZeroAuction) = _calcPrice(name);
        if (price == 0) {
            return (empty, TransferCanselReason.NOT_FOR_SALE);
        }
        if (amount < price) {
            return (empty, TransferCanselReason.LOW_TOKENS_AMOUNT);
        }
        uint32 duration = Converter.toDuration(amount, price);
        if (duration < _config.minDuration || duration > _config.maxDuration) {
            return (empty, TransferCanselReason.INVALID_DURATION);
        }
        DomainSetup setup = DomainSetup({
            owner: owner,
            price: price,
            needZeroAuction: needZeroAuction,
            reserved: false,
            expireTime: now + duration,
            amount: amount
        });
        return (setup, null);
    }

    function _calcPrice(string name) public pure returns (uint128, bool) {
        name;
        return (0, true);  // todo
    }

    function _isCorrectName(string name) private view returns (bool) {
        uint32 length = name.byteLength();
        if (length == 0 || length > _config.maxNameLength) {
            return false;
        }
        for (byte char : bytes(name)) {
            bool ok = (char > 0x3c && char < 0x7b) || (char > 0x2f && char < 0x3a) || (char == 0x2d);  // a-z0-9-
            if (!ok) {
                return false;
            }
        }
        return true;
    }

    function _register(string name, address owner, DomainSetup setup) private view {
        address nft = _nftAddressByName(_collection, name);
        TvmCell domainParams = abi.encode(_domainVersion, nft, _config, setup);
        _mintNft(name, owner, setup.expireTime);
        _deployDomain(name, domainParams);
    }

    function _mintNft(string name, address owner, uint32 expireTime) private view {
        ICollection(_collection).mint{
            value: Gas.MINT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(name, owner, expireTime, _config.expiringTimeRange);
    }

    function _deployDomain(string name, TvmCell params) private view {
        TvmCell stateInit = _buildDomainStateInit(name);
        new Platform{
            stateInit: stateInit,
            value: Gas.DEPLOY_DOMAIN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_domainCode, params, address(0));
    }

    function _execute(Action action) private pure {
        action.target.transfer({
            value: action.value,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false,
            body: action.payload
        });
    }

    function _returnToken(uint128 amount, address recipient, TransferCanselReason reason) private {
        TvmCell payload = abi.encode(reason);
        _transferToken(amount, recipient, payload);
    }

    function _transferToken(uint128 amount, address recipient, TvmCell payload) private {
        _balance -= amount;
        ITokenWallet(_wallet).transfer{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }({
            amount: amount,
            recipient: recipient,
            deployWalletValue: 0,
            remainingGasTo: recipient,
            notify: true,
            payload: payload
        });
    }


    function setDomainCode(TvmCell code) public override onlyDao cashBack {
        _domainCode = code;
        _domainVersion++;
        emit DomainCodeUpgraded(_domainVersion);
    }

    function requestDomainUpgrade(string name, uint16 version) public override onlyDomain(name) {
        if (version != _domainVersion) {
            _upgradeDomain(msg.sender, 0, MsgFlag.REMAINING_GAS);
        }
    }

    function _upgradeDomain(address domain, uint128 value, uint8 flag) private view {
        IDomain(domain).upgrade{
            value: value,
            flag: flag,
            bounce: false
        }(_domainVersion, _domainCode, _config);
    }

    function upgrade(TvmCell code) public internalMsg override onlyDao {
        emit CodeUpgraded();
        TvmCell data = abi.encode("values");  // todo values
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell input) private {
        // todo
    }

}
