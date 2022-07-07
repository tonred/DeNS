pragma ton-solidity >= 0.61.2;

import "../interfaces/IRoot.sol";
import "../interfaces/ISubdomain.sol";
import "../utils/CertificateStatus.sol";
import "../utils/Gas.sol";
import "../utils/NameChecker.sol";
import "../utils/TransferUtils.sol";
import "./Addressable.sol";


abstract contract Certificate is Addressable, TransferUtils {

    event ChangedTarget(address oldTarget, address newTarget);
    event ChangedOwner(address oldOwner, address newOwner, bool confiscate);
    event Destroyed(uint32 time);
    event CodeUpgraded(uint16 oldVersion, uint16 newVersion);


    uint256 public _id;

    string public _path;
    address private _owner;  // private in order to use from nft
    uint16 public _version;

    uint32 public _initTime;
    uint32 public _expireTime;

    address public _target;
    mapping(uint32 => bytes) public _records;


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
        TvmCell initialData;
        TvmCell initialParams;
        (_root, _platformCode, initialData, initialParams) =
            abi.decode(input, (address, TvmCell, TvmCell, TvmCell));

        _id = abi.decode(initialData, uint256);
        _init(initialParams);
    }

    function _init(TvmCell params) internal virtual;


    function getPath() public responsible returns (string path) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _path;
    }

    function getDetails() public responsible returns (address owner, uint16 version, uint32 initTime, uint32 expireTime) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_owner, _version, _initTime, _expireTime);
    }

    function getStatus() public responsible returns (CertificateStatus status) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _status();
    }

    function resolve() public responsible onActive returns (address target) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _target;
    }

    function getRecords() public responsible onActive returns (mapping(uint32 => bytes) records) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records;
    }

    function getRecord(uint32 key) public responsible onActive returns (bytes value) {
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

    function createSubdomain(string name, address owner) public onActive onlyOwner cashBack {
//        uint32 remainingLength = _config.maxNameLength - _path.byteLength() - 1;  // todo config bounce
        require(NameChecker.isCorrectName(name), 69);  // todo path + name lengths
        IRoot(_root).deploySubdomain{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_path, name, owner, _expireTime);
    }

    // can prolong only direct child, no sender check needed
    function prolongSubdomain(address subdomain) public minValue(Gas.PROLONG_SUBDOMAIN_VALUE) {
        ISubdomain(subdomain).prolong{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(_expireTime);
    }

    // todo join with previous method ?
    function confiscate(address newOwner) public onlyRoot {
//        _reserve();
        // todo nft change owner
//        emit ChangedOwner(_owner, newOwner, true);
//        _owner = newOwner;
//        newOwner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }


    function _status() internal view virtual returns (CertificateStatus);


    function requestUpgrade() public virtual;

}
