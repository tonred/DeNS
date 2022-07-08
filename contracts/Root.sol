pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/NFTCertificate.sol";
import "./abstract/Vault.sol";
import "./interfaces/IDomain.sol";
import "./interfaces/IRoot.sol";
import "./interfaces/ISubdomain.sol";
import "./interfaces/IUpgradable.sol";
import "./structures/Action.sol";
import "./structures/DeployConfigs.sol";
import "./utils/Constants.sol";
import "./utils/Converter.sol";
import "./utils/NameChecker.sol";
import "./utils/TransferKind.sol";

import "@broxus/contracts/contracts/utils/CheckPubKey.sol";


contract Root is IRoot, Collection, Vault, IUpgradable, CheckPubKey {

    event Confiscated(string path, address owner, string reason);
    event Reserved(string path, string reason);
    event DomainCodeUpgraded(uint16 newVersion);


    string public static _tld;

    address public _dao;
    bool public _active;

    RootConfig public _config;
    DomainDeployConfig _domainDeployConfig;
    SubdomainDeployConfig _subdomainDeployConfig;


    modifier onlyDao() {
        require(msg.sender == _dao, 69);
        _;
    }

    modifier onActive() {
        require(_active, 69);
        _;
    }

    modifier onlyCertificate(string path) {
        address certificate = _certificateAddress(path);
        require(msg.sender == certificate, 69);
        _;
    }

    modifier onlyDomain(string path) {
        address certificate = _certificateAddress(path);
        require(msg.sender == certificate, 69);
        // todo
        // check if Certificate is Domain (not Subdomain)
//        require(path.find(Constants.SEPARATOR).get() == path.findLast(Constants.SEPARATOR).get(), 69);
        _;
    }


    constructor(
        TvmCell nftCode,
        TvmCell indexBasisCode,
        TvmCell indexCode,
        string json,
        TvmCell platformCode,
        address token,
        address dao,
        RootConfig config,
        DomainDeployConfig domainDeployConfig,
        SubdomainDeployConfig subdomainDeployConfig
    ) public Collection(nftCode, indexBasisCode, indexCode, json, platformCode) Vault(token) checkPubKey {
        tvm.accept();
        _dao = dao;
        _config = config;
        _domainDeployConfig = domainDeployConfig;
        _subdomainDeployConfig = subdomainDeployConfig;
    }


    function getDetails() public view responsible returns (string tld, address dao, bool active) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_tld, _dao, _active);
    }

    function getConfigs() public view responsible returns (
        RootConfig config,
        DomainDeployConfig domainDeployConfig,
        SubdomainDeployConfig subdomainDeployConfig
    ) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (
            _config, _domainDeployConfig, _subdomainDeployConfig
        );
    }

    function checkName(string name) public view responsible returns (bool correct) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _isCorrectName(name);
    }

    function expectedPrice(string name) public view responsible returns (uint128 price) {
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
    ) public override onlyWallet {
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
            (string path, DomainSetup setup, optional(TransferCanselReason) error) = _buildDomainParams(name, amount, sender);
            if (error.hasValue()) {
                _returnToken(amount, sender, error.get());
                return;
            }
            _deployDomain(path, setup);
            sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
        } else if (kind == TransferKind.RENEW) {
            if (msg.value < Gas.RENEW_VALUE) {
                _returnToken(amount, sender, TransferCanselReason.LOW_MSG_VALUE);
                return;
            }
            string name = abi.decode(data, string);
            if (!_isCorrectName(name)) {
                _returnToken(amount, sender, TransferCanselReason.INVALID_NAME);
                return;
            }
            string path = _createPath(name);
            address domain = _certificateAddress(path);
            _upgradeDomain(domain, Gas.UPGRADE_DOMAIN_VALUE, 0);
            IDomain(domain).renew{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false  // todo if domain not exists
            }(amount, sender);
        } else {
            _returnToken(amount, sender, TransferCanselReason.UNKNOWN_TRANSFER);
        }
    }

    function onDomainDeployRetry(string path, uint128 amount, address sender) public override onlyDomain(path) {
        _reserve();
        _returnToken(amount, sender, TransferCanselReason.ALREADY_EXIST);
    }

    function onRenewReturn(string path, uint128 returnAmount, address sender) public override onlyDomain(path) {
        _reserve();
        _returnToken(returnAmount, sender, TransferCanselReason.DURATION_OVERFLOW);
    }

    function resolve(string path) public view responsible returns (address certificate) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _certificateAddress(path);
    }

    function deploySubdomain(string path, string name, SubdomainSetup setup) public view override onlyCertificate(path) {
        path = path + "." + name;  // todo Constants.SEPARATOR
        optional(TransferCanselReason) error;
        if (!_active) error.set(TransferCanselReason.IS_NOT_ACTIVE);
        if (!_isCorrectName(name)) error.set(TransferCanselReason.INVALID_NAME);
        if (!_isCorrectPathLength(path)) error.set(TransferCanselReason.TOO_LONG_PATH);
        if (error.hasValue()) {
            IOwner(setup.callbackTo).onSubdomainCreated{
                value: 0,
                flag: MsgFlag.REMAINING_GAS,
                bounce: false
            }(path, false, error);
            return;
        }
        _deploySubdomain(path, setup);
    }

    function confiscate(string path, address owner, string reason) public view onlyDao {
        _reserve();
        emit Confiscated(path, owner, reason);
        address certificate = _certificateAddress(path);
        NFTCertificate(certificate).confiscate{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(owner);
    }

    function reserve(string[] paths, string reason) public view onlyDao cashBack {
        for (string path : paths) {
            emit Reserved(path, reason);
            DomainSetup setup = DomainSetup({
                owner: _dao,
                price: 0,
                needZeroAuction: false,
                reserved: true,
                expireTime: 0,
                amount: 0
            });
            _deployDomain(path, setup);
        }
    }

//    function collect(uint128 amount, address staking) public view onlyDao {
//        // todo collect while exception in renew (we must return some tokens):
//        // 1) use onRenew + dont call "collect" (auto send to dao)
//        // 2) leave as is (maybe return to dao instead of staking)
//        require(amount <= _balance, 69);
//        TvmCell payload = abi.encode(reason);
//        _transferTokens(amount, staking, payload);
//    }

    // no cash back to have ability to withdraw native EVERs
    function execute(Action[] actions) public pure onlyDao {
        for (Action action : actions) {
            _execute(action);
        }
    }

    function activate() public onlyDao cashBack {
        _active = true;
    }

    function deactivate() public onlyDao cashBack {
        _active = false;
    }


    function _buildDomainParams(string name, uint128 amount, address owner) private view returns (string, DomainSetup, optional(TransferCanselReason)) {
        DomainSetup empty;
        if (!_isCorrectName(name)) {
            return ("", empty, TransferCanselReason.INVALID_NAME);
        }
        string path = _createPath(name);
        if (!_isCorrectPathLength(path)) {
            return ("", empty, TransferCanselReason.TOO_LONG_PATH);
        }
        (uint128 price, bool needZeroAuction) = _calcPrice(name);
        if (price == 0) {
            return ("", empty, TransferCanselReason.NOT_FOR_SALE);
        }
        uint32 duration = Converter.toDuration(amount, price);
        if (duration < _config.minDuration || duration > _config.maxDuration) {
            return ("", empty, TransferCanselReason.INVALID_DURATION);
        }
        DomainSetup setup = DomainSetup({
            owner: owner,
            price: price,
            needZeroAuction: needZeroAuction,
            reserved: false,
            expireTime: now + duration,
            amount: amount
        });
        return (path, setup, null);
    }

    function _isCorrectName(string name) private view inline returns (bool) {
        return NameChecker.isCorrectName(name, _config.maxNameLength);
    }

    function _isCorrectPathLength(string path) private view inline returns (bool) {
        return path.byteLength() <= _config.maxPathLength;
    }

    function _calcPrice(string name) private view returns (uint128, bool) {
        name;
        _config;
        return (0, true);  // todo price calculation
    }

    function _deployDomain(string path, DomainSetup setup) private view {
        (uint16 version, DomainConfig config, TvmCell code) = _domainDeployConfig.unpack();
        TvmCell params = abi.encode(path, version, config, setup);
        _deployCertificate(path, Gas.DEPLOY_DOMAIN_VALUE, MsgFlag.SENDER_PAYS_FEES, code, params);
    }

    function _deploySubdomain(string path, SubdomainSetup setup) private view {
        (uint16 version, TimeRangeConfig config, TvmCell code) = _subdomainDeployConfig.unpack();
        TvmCell params = abi.encode(path, version, config, setup);
        _deployCertificate(path, 0, MsgFlag.REMAINING_GAS, code, params);
    }

    function _deployCertificate(string path, uint128 value, uint8 flag, TvmCell code, TvmCell params) private view {
        uint256 id = tvm.hash(path);
        TvmCell stateInit = _buildCertificateStateInit(id);
        new Platform{
            stateInit: stateInit,
            value: value,
            flag: flag,
            bounce: false
        }(code, params);
    }

    function _createPath(string name) internal view inline returns (string) {
        return name + "." + _tld;  // todo Constants.SEPARATOR
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
        _transferTokens(amount, recipient, payload);
    }

    function _targetBalance() internal view inline override returns (uint128) {
        return Gas.ROOT_TARGET_BALANCE;
    }


    function upgradeDomain(address domain) public view override minValue(Gas.UPGRADE_DOMAIN_VALUE) {
        _upgradeDomain(domain, 0, MsgFlag.REMAINING_GAS);
    }

    function _upgradeDomain(address domain, uint128 value, uint8 flag) private view {
        (uint16 version, DomainConfig config, TvmCell code) = _domainDeployConfig.unpack();
        IDomain(domain).acceptUpgrade{
            value: value,
            flag: flag,
            bounce: false
        }(version, config, code);
    }

    function upgradeSubdomain(address subdomain) public view override minValue(Gas.UPGRADE_SUBDOMAIN_VALUE) {
        (uint16 version, TimeRangeConfig config, TvmCell code) = _subdomainDeployConfig.unpack();
        ISubdomain(subdomain).acceptUpgrade{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(version, config, code);
    }

    function upgrade(TvmCell code) public internalMsg override onlyDao {
        emit CodeUpgraded();
        TvmCell data = abi.encode("values");  // todo values
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell input) private {
        // todo onCodeUpgrade
    }

}
