pragma ton-solidity >= 0.61.2;

import "./abstract/Addressable.sol";
import "./interfaces/nft/INFT.sol";
import "./interfaces/IDomain.sol";
import "./interfaces/IRoot.sol";
import "./structures/DomainSetup.sol";
import "./utils/Converter.sol";
import "./utils/Gas.sol";
import "./utils/TransferUtils.sol";

import "@broxus/contracts/contracts/libraries/MsgFlag.sol";


abstract contract Certificate is ICertificate, Addressable, TransferUtils {

    event ChangedTarget(address oldTarget, address newTarget);
    event ChangedOwner(address oldOwner, address newOwner, bool confiscate);
    event Destroyed(uint32 time);
    event CodeUpgraded(uint16 oldVersion, uint16 newVersion);


    string public _path;

    address public _nft;
    address public _owner;
    uint16 public _version;
    Config public _config;

    uint32 public _initTime;
    uint32 public _expireTime;

    address public _target;
    mapping(string => string) public _records;

    uint16 public _subdomainVersion;
    SubdomainConfig public _subdomainConfig;
    TvmCell public _subdomainCode;


    modifier onlyOwner() {
        require(msg.sender == _owner, 69);
        _;
    }

    modifier onlyNFT() {
        require(msg.sender == _nft, 69);
        _;
    }

    modifier onStatus(CertificateStatus status) {
        require(_status() == status, 69);
        _;
    }

    modifier onActive() {
        CertificateStatus status = _status();
        require(status != CertificateStatus.EXPIRED && status != CertificateStatus.GRACE, 69);
        _;
    }


    function onCodeUpgrade(TvmCell input) private {
        tvm.resetStorage();
        TvmSlice slice = input.toSlice();
        _platformCode = slice.loadRef();

        TvmCell initialData = slice.loadRef();
        _path = abi.decode(initialData, string);

        TvmCell initialParams = slice.loadRef();
        _init(initialParams);
    }

    function _init(TvmCell params) internal virtual;


    function getPath() public responsible override returns (string path) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _path;
    }

    function getDetails() public responsible override returns (address nft, address owner, uint32 initTime, uint32 expireTime) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_nft, _owner, _initTime, _expireTime);
    }

    function getConfigDetails() public responsible override returns (uint16 version, Config config) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_version, _config);
    }

    function getStatus() public responsible override returns (CertificateStatus status) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _status();
    }

    function resolve() public responsible override onActive returns (address target) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _target;
    }

    function getRecords() public responsible override onActive returns (mapping(string => string) records) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records;
    }

    function getRecord(string key) public responsible override onActive returns (string value) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records[key];
    }


    function setTarget(address target) public override onActive onlyOwner cashBack {
        emit ChangedTarget(_target, target);
        _target = target;
        TvmCell salt = abi.encode(target);
        TvmCell code = tvm.setCodeSalt(tvm.code(), salt);
        tvm.setcode(code);
    }

    function setRecords(mapping(string => string) records) public override onActive onlyOwner cashBack {
        _records = records;
    }

    function setRecord(string key, string value) public override onActive onlyOwner cashBack {
        _records[key] = value;
    }

    function createSubdomain(string name) public override onActive onlyOwner cashBack {
        uint32 remainingLength = maxNameLength - _path.byteLength() - 1;
        require(NameChecker.isCorrectName(name), 69);
        _deploySubdomain(name);
    }

    // can prolong only direct child, no sender check needed
    function prolongSubdomain(address subdomain) public override minValue(Gas.PROLONG_SUBDOMAIN_VALUE) {
        ISubdomain(subdomain).prolong{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(_expireTime);
    }

    function onNftChangeOwner(address newOwner) public override onlyNFT {
        _reserve();
        emit ChangedOwner(_owner, newOwner, false);
        _owner = newOwner;
        newOwner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

    // todo join with previous method ?
    function confiscate(address newOwner) public override onlyRoot {
        _reserve();
        emit ChangedOwner(_owner, newOwner, true);
        _owner = newOwner;
        newOwner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

    // todo ?
    function expire() public override onStatus(CertificateStatus.EXPIRED) {
        _destroy();
    }


    function _status() internal view virtual returns (CertificateStatus);

    function _deploySubdomain(string name) private view {
        string path = name + Constants.SEPARATOR + _path;
        TvmCell stateInit = buildCertificateStateInit(path);
        TvmCell params = abi.encode(_subdomainVersion, _subdomainConfig, _subdomainCode, address(this));  // todo pack ?
        _deployCertificate(path, Gas.DEPLOY_SUBDOMAIN_VALUE, _subdomainCode, params);
    }

    function _prolongNFT() internal {
        INFT(_nft).prolong{
            value: Gas.PROLONG_NFT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_expireTime);
    }

    function _destroy() internal {
        emit Destroyed(now);
        INFT(_nft).burn{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO,
            bounce: false
        }();
    }


    function requestUpgrade() public override minValue(Gas.REQUEST_UPGRADE_DOMAIN_VALUE) {
        // todo virtual
        IRoot(_root).requestDomainUpgrade{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(_path, _version, bool domainOrSubdomain);  // todo domainOrSubdomain
    }

    function upgrade(uint16 version, TvmCell code, Config config) public override onlyRoot {
        if (version == _version) {
            _owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
            return;
        }
        _upgrade(version, code, config);
    }

    function _upgrade(uint16 version, TvmCell code, Config config) private {
        emit CodeUpgraded(_version, version);
        _version = version;
        _config = config;
        TvmCell data = abi.encode("xxx");  // todo values
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(data);
    }

}
