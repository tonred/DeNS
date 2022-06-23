pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/Addressable.sol";
import "./interfaces/nft/INFT.sol";
import "./interfaces/IDomain.sol";
import "./interfaces/IRoot.sol";
import "./structures/DomainSetup.sol";
import "./utils/Converter.sol";
import "./utils/Gas.sol";
import "./utils/TransferUtils.sol";

import "@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract Domain is IDomain, Addressable, TransferUtils {

    event ZeroAuctionStarted();
    event ZeroAuctionFinished();
    event Prolonged(uint32 time, uint32 duration, uint32 newExpireTime);
    event ChangedOwner(address oldOwner, address newOwner, bool confiscate);
    event Destroyed(uint32 time);
    event CodeUpgraded(uint16 oldVersion, uint16 newVersion);


    string public _name;

    address public _nft;
    address public _owner;
    uint16 public _version;
    Config public _config;

    uint128 public _defaultPrice;
    uint128 public _currentPrice;
    bool public _inZeroAuction;
    bool public _needZeroAuction;
    bool public _reserved;

    uint32 public _initTime;
    uint32 public _expireTime;

    address public _target;
    mapping(uint256 /*group*/ => mapping(uint256 /*hash*/ => string[] /*values*/)) public _records;


    modifier onlyOwner() {
        require(msg.sender == _owner, 69);
        _;
    }

    modifier onlyNFT() {
        require(msg.sender == _nft, 69);
        _;
    }

    modifier onStatus(DomainStatus status) {
        require(_status() == status, 69);
        _;
    }

    modifier onActive() {
        DomainStatus status = _status();
        require(status != DomainStatus.EXPIRED && status != DomainStatus.GRACE, 69);
        _;
    }


    function onCodeUpgrade(TvmCell input) private {
        tvm.resetStorage();
        TvmSlice slice = input.toSlice();
        (_root, /*type*/, /*remainingGasTo*/) = slice.decode(address, uint8, address);
        _platformCode = slice.loadRef();

        TvmCell initialData = slice.loadRef();
        _name = abi.decode(initialData, string);

        TvmCell initialParams = slice.loadRef();
        _init(initialParams);
    }

    // 0x3f61459c is Platform constructor functionID
    function onDeployRetry(TvmCell code, TvmCell params, address /*remainingGasTo*/) public override functionID(0x3f61459c) onlyRoot {
        (uint16 version, /*nft*/, Config config, DomainSetup setup) = abi.decode(params, (uint16, address, Config, DomainSetup));
        if (_status() == DomainStatus.EXPIRED) {
            if (version != _version) {
                _upgrade(version, code, config);
            }
            _init(params);
        } else {
            if (setup.reserved) {
                _root.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
            } else {
                IRoot(_root).onDomainDeployRetry{
                    value: 0,
                    flag: MsgFlag.REMAINING_GAS,
                    bounce: false
                }(_name, setup.amount, setup.owner);
            }
        }
    }

    function _init(TvmCell params) private {
        DomainSetup setup;
        (_version, _nft, _config, setup) = abi.decode(params, (uint16, address, Config, DomainSetup));
        (_owner, _defaultPrice, _needZeroAuction, _reserved, _expireTime, /*amount*/) = setup.unpack();
        _currentPrice = _defaultPrice;
        _initTime = now;
    }


    function getName() public responsible override returns (string name) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _name;
    }

    function getDetails() public responsible override returns (
        address nft, address owner, uint128 defaultPrice, uint128 currentPrice, uint32 initTime, uint32 expireTime
    ) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_nft, _owner, _defaultPrice, _currentPrice, _initTime, _expireTime);
    }

    function getConfigDetails() public responsible override returns (Config config) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _config;
    }

    function getAuctionDetails() public responsible override returns (bool inZeroAuction, bool needZeroAuction) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_inZeroAuction, _needZeroAuction);
    }

    function getStatus() public responsible override returns (DomainStatus status) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _status();
    }


    function resolve() public responsible override onActive returns (address target) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _target;
    }

    function resolveQuery(string group, string query) public responsible override onActive returns (optional(string[]) values) {
        // check if group exists
        uint256 groupHash = tvm.hash(group);
        if (!_records.exists(groupHash)) {
            return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} null;
        }
        mapping(uint256 => string[]) records = _records[groupHash];
        // firstly, check full match like "a.b.c"
        values = _getRecordValues(records, query);
        if (values.hasValue()) {
            return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} values;
        }
        // secondly, try regex partially math like "*.c"
        uint i = 0;
        uint length = query.byteLength();
        // todo try for loop for gas optimization
        for (byte char : bytes(query)) {
            if (char == ".") {
                string part = "*" + query.substr(i, length - i);
                values = _getRecordValues(records, part);
                if (values.hasValue()) {
                    return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} values;
                }
            }
            i++;
        }
        // finally, check "*"
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _getRecordValues(records, "*");
    }

    function getRecordsCount(string group) public responsible override returns (uint256 count) {
        uint256 groupHash = tvm.hash(group);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _records[groupHash].keys().length;
    }

    function checkRecords(string group, InputRecord[] records) public responsible override onActive returns (bool correct) {
        if (!_isValidGroup(group)) {
            return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} false;
        }
        for (InputRecord record : records) {
            if (!_isValidRecord(record)) {
                return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} false;
            }
        }
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} true;
    }

    function setTarget(address target) public override onActive onlyOwner cashBack {
        _target = target;
    }

    function setRecords(string group, InputRecord[] records) public override onActive onlyOwner cashBack {
        require(_isValidGroup(group), 69);
        delete _records;
        uint256 groupHash = tvm.hash(group);
        for (InputRecord record : records) {
            _setRecord(groupHash, record);
        }
    }

    function setRecord(string group, InputRecord record) public override onActive onlyOwner cashBack {
        require(_isValidGroup(group), 69);
        uint256 groupHash = tvm.hash(group);
        _setRecord(groupHash, record);
    }

    function deleteRecords(string group, string[] templates) public override onActive onlyOwner cashBack {
        require(_isValidGroup(group), 69);
        uint256 groupHash = tvm.hash(group);
        for (string template : templates) {
            uint256 templateHash = tvm.hash(template);
            delete _records[groupHash][templateHash];  // todo check if value exists ?
        }
    }

    function startZeroAuction() public override onStatus(DomainStatus.NEW) minValue(Gas.START_ZERO_AUCTION_VALUE) {
        // todo

        emit ZeroAuctionStarted();
        _inZeroAuction = true;
    }

    function zeroAuctionFinished() public override onStatus(DomainStatus.IN_ZERO_AUCTION) {
        // todo
//        require(msg.sender == _auction, 69);

        emit ZeroAuctionFinished();
//        _auction = address.makeAddrNone();
        _inZeroAuction = false;
        _needZeroAuction = true;
//        _currentPrice = auctionPrice;
    }

    // duration - time for prolonging from now
    function expectedProlongAmount(uint32 duration) public responsible override returns (uint128 amount) {
        DomainStatus status = _status();
        if (duration > _config.maxDuration || now + duration <= _expireTime || status == DomainStatus.RESERVED) {
            return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} 0;
        }
        uint32 increase = now + duration - _expireTime;
        uint128 price = _calcProlongPrice(status);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} Converter.toAmount(increase, price);
    }

    function prolong(uint128 amount, address sender) public override onlyRoot {
        DomainStatus status = _status();
        if (sender != _owner || now + _config.maxDuration <= _expireTime || status == DomainStatus.RESERVED) {
            // wrong sender OR already prolonged for max period OR reserved
            IRoot(_root).onProlongReturn{
                value: 0,
                flag: MsgFlag.REMAINING_GAS,
                bounce: false
            }(_name, amount, sender);
            return;
        }

        _reserve();  // todo move up in case of using target balance
        uint128 price = _calcProlongPrice(status);
        uint32 maxIncrease = now + _config.maxDuration - _expireTime;
        uint128 maxAmount = Converter.toAmount(maxIncrease, price);
        uint128 returnAmount = (maxAmount < amount) ? (amount - maxAmount) : 0;
        amount = math.max(amount, maxAmount);

        uint32 duration = Converter.toDuration(amount, price);
        _expireTime += duration;
        emit Prolonged(now, duration, _expireTime);

        INFT(_nft).prolong{
            value: Gas.PROLONG_NFT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_expireTime);

        if (returnAmount > 0) {
            IRoot(_root).onProlongReturn{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false
            }(_name, returnAmount, sender);
        } else {
            _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
        }
    }

    function nftOwnerChanged(address newOwner) public override onlyNFT {
        _reserve();
        emit ChangedOwner(_owner, newOwner, false);
        _owner = newOwner;
        newOwner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

    function confiscate(address newOwner) public override onlyRoot {
        _reserve();
        emit ChangedOwner(_owner, newOwner, true);
        _owner = newOwner;
        newOwner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

    function unreserve(address owner, uint128 price, uint32 expireTime, bool needZeroAuction) public override onlyRoot {
        _owner = owner;
        _defaultPrice = _currentPrice = price;
        _needZeroAuction = needZeroAuction;
        _reserved = false;
        _initTime = now;
        _expireTime = expireTime;
        INFT(_nft).unreserve{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(owner, expireTime);
    }

    function expire() public override onStatus(DomainStatus.EXPIRED) {
        tvm.accept();
        _destroy();
    }


    function _status() private view returns (DomainStatus) {
        int64 passed = int64(now) - _initTime;
        int64 left = int64(_expireTime) - now;
        if (_reserved) {
            return DomainStatus.RESERVED;
        } else if (_inZeroAuction) {
            return DomainStatus.IN_ZERO_AUCTION;
        } else if (passed < _config.startZeroAuctionTimeRange && !_needZeroAuction) {
            return DomainStatus.NEW;
        } else if (left < -_config.graceTimeRange) {
            return DomainStatus.EXPIRED;
        } else if (left < 0) {
            return DomainStatus.GRACE;
        } else if (left < _config.expiringTimeRange) {
            return DomainStatus.EXPIRING;
        } else {
            return DomainStatus.COMMON;
        }
    }

    function _calcProlongPrice(DomainStatus status) private view inline returns (uint128) {
        uint128 price = _currentPrice;  // todo _defaultPrice VS _currentPrice
        if (status == DomainStatus.GRACE) {
            price += math.muldiv( _config.graceFinePercent, price, Constants.PERCENT_DENOMINATOR);
        } else if (status == DomainStatus.EXPIRED) {
           price += math.muldiv( _config.expiredFinePercent, price, Constants.PERCENT_DENOMINATOR);
        }
        return price;
    }

    function _getRecordValues(mapping(uint256 => string[]) records, string query) private pure inline returns (optional(string[]) values) {
        uint256 hash = tvm.hash(query);
        return records.fetch(hash);
    }

    function _setRecord(uint256 groupHash, InputRecord record) private inline {
        require(_isValidRecord(record), 69);
        uint256 templateHash = tvm.hash(record.template);
        _records[groupHash][templateHash] = record.values;
    }

    function _isValidGroup(string group) private pure inline returns (bool) {
        if (group.byteLength() == 0) {
            return false;
        }
        for (byte char : bytes(group)) {
            bool ok = char > 0x3c && char < 0x7b;  // a-z
            if (!ok) {
                return false;
            }
        }
        return true;
    }

    function _isValidRecord(InputRecord record) private pure inline returns (bool) {
        if (record.template.byteLength() == 0 || record.values.length == 0) {
            return false;
        }
        bool prevIsDot = true;  // first char cannot be dot
        for (byte char : bytes(record.template)) {
            if (char == ".") {
                if (prevIsDot) {
                    return false;
                }
                prevIsDot = true;
            } else {
                bool ok = (char > 0x3c && char < 0x7b) || (char > 0x2f && char < 0x3a) || (char == 0x2d);  // a-z0-9-
                if (!ok) {
                    return false;
                }
                prevIsDot = false;
            }
        }
        return !prevIsDot;  // last char cannot be dot
    }

    function _destroy() private view {
        emit Destroyed(now);
        INFT(_nft).burn{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO,
            bounce: false
        }();
    }


    function requestUpgrade() public override minValue(Gas.REQUEST_UPGRADE_DOMAIN_VALUE) {
        IRoot(_root).requestDomainUpgrade{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(_name, _version);
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
