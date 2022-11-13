pragma ever-solidity ^0.63.0;

import "../interfaces/ICertificate.sol";
import "../interfaces/IRoot.sol";
import "../interfaces/ISubdomain.sol";
import "../utils/Constants.sol";
import "../utils/ErrorCodes.sol";
import "../utils/Gas.sol";
import "../utils/NameChecker.sol";
import "../utils/TransferUtils.sol";

import {BaseSlave, Version, ErrorCodes as VersionableErrorCodes} from "versionable/contracts/BaseSlave.sol";


abstract contract Certificate is ICertificate, BaseSlave, TransferUtils {

    event ChangedTarget(address oldTarget, address newTarget);
    event ChangedOwner(address oldOwner, address newOwner, bool confiscate);


    uint256 public _id;
    address public _root;

    string public _path;
    uint32 public _initTime;
    uint32 public _expireTime;

    address public _target;
    mapping(uint32 => TvmCell) public _records;


    modifier onlyRoot() {
        require(msg.sender == _root, ErrorCodes.IS_NOT_ROOT);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == _getOwner(), ErrorCodes.IS_NOT_OWNER);
        _;
    }

    modifier onStatus(CertificateStatus status) {
        require(_status() == status, ErrorCodes.WRONG_STATUS);
        _;
    }

    modifier onActive() {
        CertificateStatus status = _status();
        require(status != CertificateStatus.EXPIRED && status != CertificateStatus.GRACE, ErrorCodes.IS_NOT_ACTIVE);
        _;
    }


    function onCodeUpgrade(TvmCell input, bool upgrade) internal {
        if (!upgrade) {
            tvm.resetStorage();
            (address root, TvmCell initialData, TvmCell initialParams) =
                abi.decode(input, (address, TvmCell, TvmCell));
            _root = root;
            _id = abi.decode(initialData, uint256);
            _initTime = now;
            _target = address.makeAddrNone();
            _init(initialParams);
        } else {
            // revert(VersionableErrorCodes.INVALID_OLD_VERSION);
            // Salt code with target address (on upgrade)
            if (!_target.isNone()) {
                _updateCodeSalt();
            }
        }
    }

    function _init(TvmCell params) internal virtual;


    function getPath() public view responsible override returns (string path) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _path;
    }

    function getDetails() public view responsible override returns (address owner, uint32 initTime, uint32 expireTime) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_getOwner(), _initTime, _expireTime);
    }

    function getStatus() public view responsible override returns (CertificateStatus status) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _status();
    }

    function resolve() public view responsible override onActive returns (address target) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _target;
    }

    function query(uint32 key) public view responsible override onActive returns (optional(TvmCell) value) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records.fetch(key);
    }

    function getRecords() public view responsible override onActive returns (mapping(uint32 => TvmCell) records) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records;
    }


    function setTarget(address target) public override onActive onlyOwner cashBack {
        _setTarget(target);
    }

    function setRecords(mapping(uint32 => TvmCell) records) public override onActive onlyOwner cashBack {
        for ((uint32 key, TvmCell value) : records) {
            _setRecord(key, value);
        }
    }

    function setRecord(uint32 key, TvmCell value) public override onActive onlyOwner cashBack {
        _setRecord(key, value);
    }

    function deleteRecords(uint32[] keys) public override onActive onlyOwner cashBack {
        for (uint32 key : keys) {
            _deleteRecord(key);
        }
    }

    function deleteRecord(uint32 key) public override onActive onlyOwner cashBack {
        _deleteRecord(key);
    }

    function createSubdomain(string name, address owner, bool renewable) public view override onlyOwner cashBack {
        CertificateStatus status = _status();
        require(
            status == CertificateStatus.COMMON ||
            status == CertificateStatus.EXPIRING ||
            (status == CertificateStatus.RESERVED && renewable),
            ErrorCodes.WRONG_STATUS
        );
        SubdomainSetup setup = SubdomainSetup({
            owner: owner,
            creator: msg.sender,
            expireTime: _expireTime,
            parent: address(this),
            renewable: renewable
        });
        IRoot(_root).deploySubdomain{
            value: Gas.DEPLOY_SUBDOMAIN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_path, name, setup);
    }

    // renew only direct child, anyone can call
    function renewSubdomain(address subdomain) public view override onActive minValue(Gas.RENEW_SUBDOMAIN_VALUE) {
        ISubdomain(subdomain).renew{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(_expireTime);
    }


    function _setRecord(uint32 key, TvmCell value) private {
        if (key == Constants.TARGET_RECORD_ID) {
            (uint16 bits, uint8 refs) = value.toSlice().size();
            require(bits == Constants.ADDRESS_SIZE && refs == 0, ErrorCodes.INVALID_ADDRESS_CELL);
            _setTarget(abi.decode(value, address));
        } else {
            value.dataSize(Constants.MAX_CELLS);  // can raise exception 8 (cell overflow)
            _records[key] = value;
        }
    }

    function _deleteRecord(uint32 key) private {
        if (key == Constants.TARGET_RECORD_ID) {
            _setTarget(address.makeAddrNone());
        } else {
            delete _records[key];
        }
    }

    function _setTarget(address target) private {
        require(target.isStdAddrWithoutAnyCast() || target.isNone(), ErrorCodes.INVALID_ADDRESS_TYPE);
        if (target == _target) {
            return;
        }
        emit ChangedTarget(_target, target);
        _target = target;
        _records[Constants.TARGET_RECORD_ID] = abi.encode(target);
        _updateCodeSalt();
    }

    function _updateCodeSalt() private view {
        TvmCell encoded = abi.encode(_target);
        TvmCell code = tvm.setCodeSalt(tvm.code(), encoded);
        tvm.setcode(code);
    }

    function _getOwner() internal view virtual returns (address);

    function _status() internal view virtual returns (CertificateStatus);


    function requestUpgrade() public view override cashBack {
        IRoot(_root).upgradeToLatest{
            value: Gas.UPGRADE_SLAVE_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_sid, address(this), msg.sender);
    }

    function acceptUpgrade(uint16 sid, Version version, TvmCell code, TvmCell params, address remainingGasTo) public override onlyRoot {
        _acceptUpgrade(sid, version, code, params, remainingGasTo);
    }

    function _onCodeUpgrade(TvmCell data, Version oldVersion, TvmCell params, address remainingGasTo) internal override {
        TvmCell input = abi.encode(data, oldVersion, params, remainingGasTo);
        onCodeUpgrade(input, true);
    }


    onBounce(TvmSlice body) external view {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(renewSubdomain)) {
            // subdomain is not exist
            _getOwner().transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
        }
    }

}
