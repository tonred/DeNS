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

    event Confiscated(string path, address owner, string reason);
    event Reserved(string path, string reason);
    event DomainCodeUpgraded(uint16 newVersion);


    string public static _tld;

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

    modifier onlyDomain(string path) {
        // todo is not subdomain !!!
        address domain = _certificateAddress(path);
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
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} NameChecker.isCorrectName(name);
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
            _register(name, setup);
            sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
        } else if (kind == TransferKind.PROLONG) {
            if (msg.value < Gas.PROLONG_VALUE) {
                _returnToken(amount, sender, TransferCanselReason.LOW_MSG_VALUE);
                return;
            }
            string name = abi.decode(data, string);
            if (!NameChecker.isCorrectName(name)) {
                _returnToken(amount, sender, TransferCanselReason.INVALID_NAME);
                return;
            }
            string path = _createPath(name);
            address domain = _certificateAddress(path);
            ICodeStorage(domain).upgradeDomain{
                value: Gas.REQUEST_UPGRADE_DOMAIN_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES,
                bounce: false
            }();
            IDomain(domain).prolong{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false  // todo if domain not exists
            }(amount, sender);
        } else {
            _returnToken(amount, sender, TransferCanselReason.UNKNOWN_TYPE);
        }
    }

    function onDomainDeployRetry(string path, uint128 amount, address sender) public override onlyDomain(path) {
        _reserve();
        _returnToken(amount, sender, TransferCanselReason.ALREADY_EXIST);
    }

    function onProlongReturn(string path, uint128 returnAmount, address sender) public override onlyDomain(path) {
        _reserve();
        _returnToken(returnAmount, sender, TransferCanselReason.DURATION_OVERFLOW);
    }

    function resolve(string path) public responsible override returns (address certificate) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _certificateAddress(path);
    }

    function confiscate(string path, address owner, string reason) public override onlyDao {
        _reserve();
        emit Confiscated(path, owner, reason);
        address domain = _certificateAddress(path);
        IDomain(domain).confiscate{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(owner);
    }

    function reserve(string[] names, bool ignoreNameCheck, string reason) public override onlyDao {  // todo path
        _reserve();
        for (string name : names) {
            require(NameChecker.isCorrectName(name) || ignoreNameCheck, 69);
            emit Reserved(name, reason);
            DomainSetup setup = DomainSetup({
                owner: _dao,
                price: 0,
                needZeroAuction: false,
                reserved: true,
                expireTime: 0,
                amount: 0
            });
            _register(name, setup);
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
        if (!NameChecker.isCorrectName(name)) {
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

    function _register(string name, DomainSetup setup) private view {  // todo name or path
        string path = _createPath(name);
        ICodeStorage.registerDomain{
            value: 0,  // todo
            flag: 0,  //todo
            bounce: false
        }(path, setup);
    }

    function _createPath(string name) internal inline returns (string) {
        return name + Constants.SEPARATOR + _tld;
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
