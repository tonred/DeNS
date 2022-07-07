pragma ton-solidity >= 0.61.2;

import "../interfaces/IRoot.sol";
import "../interfaces/ISubdomain.sol";
import "../utils/CertificateStatus.sol";
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
    address private _owner;  // private in order to use from nft
    uint16 public _version;

    uint32 public _initTime;
    uint32 public _expireTime;

    address public _target;
    mapping(uint32 => bytes) public _records;


    modifier onlyRoot() {  // todo move in inheritance up ?
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

    function resolve() public view responsible onActive returns (address target) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _target;
    }

    function getRecords() public view responsible onActive returns (mapping(uint32 => bytes) records) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records;
    }

    function getRecord(uint32 key) public view responsible onActive returns (bytes value) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records[key];
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

    function createSubdomain(string name, address owner, bool renewable, address callbackTo) public view onActive onlyOwner cashBack {
        SubdomainSetup setup = SubdomainSetup(owner, _expireTime, address(this), renewable, callbackTo);
        IRoot(_root).deploySubdomain{
            value: Gas.DEPLOY_SUBDOMAIN_VALUE,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_path, name, setup);
    }

    // can prolong only direct child, no sender check needed
    function prolongSubdomain(address subdomain) public view onActive minValue(Gas.PROLONG_SUBDOMAIN_VALUE) {
        ISubdomain(subdomain).prolong{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(_expireTime);
    }


    function _status() internal view virtual returns (CertificateStatus);

    function requestUpgrade() public virtual;

    onBounce(TvmSlice body) external view {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(prolongSubdomain)) {
            // subdomain is not exist
            _owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
        }
    }

}
