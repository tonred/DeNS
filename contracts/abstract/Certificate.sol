pragma ton-solidity >= 0.61.2;

import "../enums/CertificateStatus.sol";
import "../interfaces/IRoot.sol";
import "../interfaces/ISubdomain.sol";
import "../utils/Gas.sol";
import "../utils/NameChecker.sol";
import "../utils/TransferUtils.sol";


abstract contract Certificate is TransferUtils {

    event ChangedTarget(address oldTarget, address newTarget);
    event ChangedOwner(address oldOwner, address newOwner, bool confiscate);
    event Destroyed(uint32 time);
    event CodeUpgraded(uint16 oldVersion, uint16 newVersion);


    uint256 public _id;
    address public _root;

    string public _path;
    address private _owner;  // private in order to be compatible with nft  // todo test (in case of bug - use _getOwner() method)
    uint16 public _version;

    uint32 public _initTime;
    uint32 public _expireTime;

    address public _target;
    mapping(uint32 => bytes) public _records;


    modifier onlyRoot() {
        require(msg.sender == _root, 69);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, 69);
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


    function onCodeUpgrade(TvmCell input) internal {
        tvm.resetStorage();
        (address root, TvmCell initialData, TvmCell initialParams) =
            abi.decode(input, (address, TvmCell, TvmCell));
        _root = root;
        _id = abi.decode(initialData, uint256);
        _init(initialParams);
    }

    function _init(TvmCell params) internal virtual;


    function getPath() public view responsible returns (string path) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _path;
    }

    function getDetails() public view responsible returns (address owner, uint16 version, uint32 initTime, uint32 expireTime) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_owner, _version, _initTime, _expireTime);
    }

    function getStatus() public view responsible returns (CertificateStatus status) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _status();
    }

    // todo naming
    function resolve() public view responsible onActive returns (address target) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _target;
    }

    function query(uint32 key) public view responsible onActive returns (bytes value) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records[key];
    }

    function getRecords() public view responsible onActive returns (mapping(uint32 => bytes) records) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records;
    }


    function setTarget(address target) public onActive onlyOwner cashBack {
        emit ChangedTarget(_target, target);
        _target = target;
        TvmCell salt = abi.encode(target);
        TvmCell code = tvm.setCodeSalt(tvm.code(), salt);
        tvm.setcode(code);
    }

    function setRecords(mapping(uint32 => bytes) records) public onActive onlyOwner cashBack {
        _records = records;
    }

    function setRecord(uint32 key, bytes value) public onActive onlyOwner cashBack {
        _records[key] = value;
    }

    function createSubdomain(string name, address owner, bool renewable) public view onlyOwner cashBack {
        CertificateStatus status = _status();
        require(status == CertificateStatus.COMMON || status == CertificateStatus.EXPIRING, 69);
        SubdomainSetup setup = SubdomainSetup({
            owner: owner,
            creator: msg.sender,
            expireTime: _expireTime,
            parent: address(this),
            renewable: renewable
        });
        IRoot(_root).deploySubdomain{
            value: Gas.DEPLOY_SUBDOMAIN_VALUE,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_path, name, setup);
    }

    // can renew only direct child, no sender check needed
    function renewSubdomain(address subdomain) public view onActive minValue(Gas.RENEW_SUBDOMAIN_VALUE) {
        ISubdomain(subdomain).renew{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(_expireTime);
    }


    function _status() internal view virtual returns (CertificateStatus);

    function requestUpgrade() public virtual;

    onBounce(TvmSlice body) external view {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(renewSubdomain)) {
            // subdomain is not exist
            _owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
        }
    }

}
