pragma ever-solidity ^0.63.0;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IDomain.sol";
import "./interfaces/outer/IOwner.sol";
import "./abstract/NFTCertificate.sol";
import "./utils/Converter.sol";

import "./auction/MarketOffer.sol";


contract Domain is IDomain, NFTCertificate {

    event ZeroAuctionStarted(address zeroAuction);
    event ZeroAuctionFinished(address newOwner);
    event Renewed(uint32 time, uint32 duration, uint32 newExpireTime);


    DurationConfig public _durationConfig;
    DomainConfig public _config;

    uint128 public _price;
    bool public _reserved;

    bool public _inZeroAuction;
    bool public _needZeroAuction;
    address public _auctionRoot;
    address public _zeroAuction;
    uint128 public _initialAmount;
    address public _initialOwner;


    modifier onActiveNotNew() {
        CertificateStatus status = _status();
        require(
            status != CertificateStatus.EXPIRED &&
            status != CertificateStatus.GRACE &&
            status != CertificateStatus.NEW,
            ErrorCodes.IS_NOT_ACTIVE
        );
        _;
    }


    // 0x4A2E4FD6 is a Platform constructor functionID
    function onDeployRetry(TvmCell /*code*/, TvmCell params) public functionID(0x4A2E4FD6) override onlyRoot {
        (/*path*/, /*durationConfig*/, /*config*/, DomainSetup setup, /*indexCode*/)
            = abi.decode(params, (string, DurationConfig, DomainConfig, DomainSetup, TvmCell));
        if (setup.reserved) {
            _root.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
            return;
        }
        IRoot(_root).returnTokensFromDomain{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(_path, setup.amount, setup.owner, TransferBackReason.ALREADY_EXIST);
        if (_status() == CertificateStatus.EXPIRED) {
            _destroy();
        }
    }

    function _init(TvmCell params) internal override {
        _reserve();
        _initVersion(Constants.DOMAIN_SID, Version(Constants.DOMAIN_VERSION_MAJOR, Constants.DOMAIN_VERSION_MINOR));
        DomainSetup setup;
        TvmCell indexCode;
        (_path, _durationConfig, _config, setup, indexCode) =
            abi.decode(params, (string, DurationConfig, DomainConfig, DomainSetup, TvmCell));
        (_owner, _price, _reserved, _needZeroAuction, _expireTime, _initialAmount) = setup.unpack();
        _auctionRoot = _zeroAuction = address.makeAddrNone();
        _initialOwner = _owner;
        _initNFT(_owner, _owner, indexCode, _owner);
    }


    function getDurationConfig() public view responsible override returns (DurationConfig durationConfig) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _durationConfig;
    }

    function getConfig() public view responsible override returns (DomainConfig config) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _config;
    }

    function getPrice() public view responsible override returns (uint128 price) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _price;
    }

    function getFlags() public view responsible override returns (bool reserved, bool inZeroAuction, bool needZeroAuction) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_reserved, _inZeroAuction, _needZeroAuction);
    }

    function getZeroAuction() public view responsible override returns (optional(address) zeroAuction) {
        if (!_zeroAuction.isNone()) {
            zeroAuction.set(_zeroAuction);
        }
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} zeroAuction;
    }


    function startZeroAuction(AuctionConfig config, uint128 amount, address sender) public override onlyRoot {
        if (_status() != CertificateStatus.NEW) {
            IRoot(_root).returnTokensFromDomain{
                value: 0,
                flag: MsgFlag.REMAINING_GAS,
                bounce: false
            }(_path, amount, sender, TransferBackReason.INVALID_STATUS);
            return;
        }
        _inZeroAuction = true;
        _auctionRoot = config.auctionRoot;
        mapping(address => CallbackParams) callbacks;
        TvmCell payload = _buildZeroAuctionPayload(config);
        callbacks[config.auctionRoot] = CallbackParams(Gas.CREATE_ZERO_AUCTION_VALUE, payload);
        _manager = _root;   // in order to pass `onlyManager` modifier in `changeManager`
        _owner = _root;     // in order to receive tokens on Root from Auction
        changeManager(config.auctionRoot, sender, callbacks);
    }

    function changeOwner(
        address newOwner, address sendGasTo, mapping(address => CallbackParams) callbacks
    ) public override onlyManager onActiveNotNew {
        super.changeOwner(newOwner, sendGasTo, callbacks);
    }

    function changeManager(
        address newManager, address sendGasTo, mapping(address => CallbackParams) callbacks
    ) public override onlyManager onActiveNotNew {
        if (_inZeroAuction) {
            if (msg.sender == _auctionRoot) {
                // Auction started
                _owner = _initialOwner;
                _zeroAuction = newManager;
                emit ZeroAuctionStarted(_zeroAuction);
                IRoot(_root).zeroAuctionInitialBid{
                    value: Gas.ZERO_AUCTION_BID_VALUE,
                    flag: MsgFlag.SENDER_PAYS_FEES,
                    bounce: false
                }(_path, _zeroAuction, _initialAmount, _initialOwner);
            } else if (msg.sender == _zeroAuction) {
                // Auction finished (canceled)
                // this cannot happen, but for safety lets return ownership
                newManager = _initialOwner;  // `newManager` is `Root`, changing it
                _finishZeroAuction(newManager);
            }
        }
        super.changeManager(newManager, sendGasTo, callbacks);
    }

    function transfer(
        address to, address sendGasTo, mapping(address => CallbackParams) callbacks
    ) public override onlyManager onActiveNotNew {
        if (msg.sender == _zeroAuction) {
            // Auction finished (completed)
            _finishZeroAuction(to);
        }
        super.transfer(to, sendGasTo, callbacks);
    }


    function expectedRenewAmount(uint32 newExpireTime) public view responsible override returns (uint128 amount) {
        if (newExpireTime <= _expireTime || newExpireTime > now + _config.maxDuration || !_isRenewAllowedForStatus()) {
            return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} 0;
        }
        uint32 increase = newExpireTime - _expireTime;
        uint128 price = _calcRenewPrice();
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} Converter.toAmount(increase, price);
    }

    function renew(uint128 amount, address sender) public override onlyRoot {
        _reserve();
        optional(TransferBackReason) error = _isRenewAllowed(sender);
        if (error.hasValue()) {
            // invalid status OR invalid sender OR already renewed for max period
            IRoot(_root).returnTokensFromDomain{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false
            }(_path, amount, sender, error.get());
            return;
        }

        uint128 price = _calcRenewPrice();
        uint32 maxIncrease = now + _config.maxDuration - _expireTime;
        uint128 maxAmount = Converter.toAmount(maxIncrease, price);
        uint128 returnAmount = (maxAmount < amount) ? (amount - maxAmount) : 0;
        amount = math.min(amount, maxAmount);

        uint32 duration = Converter.toDuration(amount, price);
        _expireTime += duration;
        emit Renewed(now, duration, _expireTime);

        CertificateStatus status = _status();
        if (status == CertificateStatus.NEW) {
            _initialAmount += amount;
        }

        if (returnAmount > 0) {
            IRoot(_root).returnTokensFromDomain{
                value: Gas.RETURN_TOKENS_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES,
                bounce: false
            }(_path, returnAmount, sender, TransferBackReason.DURATION_OVERFLOW);
        }
        IOwner(_owner).onRenewed{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_path, _expireTime);
    }

    function unreserve(address owner, uint128 price, uint32 expireTime, bool needZeroAuction) public override onlyRoot {
        _transfer(owner);
        _price = price;
        _needZeroAuction = needZeroAuction;
        _reserved = false;
        _initTime = now;
        _expireTime = expireTime;
        IOwner(owner).onUnreserved{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(_path, expireTime);
    }


    function _status() internal view override returns (CertificateStatus) {
        int64 passed = int64(now) - _initTime;
        int64 left = int64(_expireTime) - now;
        if (_reserved) {
            return CertificateStatus.RESERVED;
        } else if (_inZeroAuction) {
            return CertificateStatus.IN_ZERO_AUCTION;
        } else if (passed < _durationConfig.startZeroAuction && _needZeroAuction) {
            return CertificateStatus.NEW;
        } else if (left < -_durationConfig.grace) {
            return CertificateStatus.EXPIRED;
        } else if (left < 0) {
            return CertificateStatus.GRACE;
        } else if (left < _durationConfig.expiring) {
            return CertificateStatus.EXPIRING;
        } else {
            return CertificateStatus.COMMON;
        }
    }

    function _buildZeroAuctionPayload(AuctionConfig config) private view inline returns (TvmCell) {
        TvmBuilder builder;
        builder.store(uint32(0), config.tokenRoot, _initialAmount, uint64(now), uint64(config.duration));
        return builder.toCell();
    }

    function _finishZeroAuction(address newOwner) private {
        emit ZeroAuctionFinished(newOwner);
        _inZeroAuction = false;
        _needZeroAuction = false;
    }

    function _isRenewAllowed(address sender) private view inline returns(optional(TransferBackReason)) {
        if (!_isRenewAllowedForStatus()) {
            return TransferBackReason.INVALID_STATUS;
        } else if (sender != _owner) {
            return TransferBackReason.INVALID_SENDER;
        } else if (now + _config.maxDuration <= _expireTime) {
            return TransferBackReason.ALREADY_RENEWED;
        } else {
            return null;
        }
    }

    function _isRenewAllowedForStatus() private view inline returns(bool) {
        CertificateStatus status = _status();
        return (
            status != CertificateStatus.RESERVED &&
            status != CertificateStatus.EXPIRED &&
            status != CertificateStatus.IN_ZERO_AUCTION
        );
    }

    function _calcRenewPrice() private view inline returns (uint128) {
        uint128 price = _price;
        if (_status() == CertificateStatus.GRACE) {
            price += math.muldiv(_config.graceFinePercent, price, Constants.PERCENT_DENOMINATOR);
        }
        return price;
    }

    function _targetBalance() internal view inline override returns (uint128) {
        return Gas.DOMAIN_TARGET_BALANCE;
    }


    function _encodeContractData() internal override returns (TvmCell) {
        return abi.encode(
            _owner, _manager, _indexCode,  // NFTBase4_1 + NFTBase4_3
            _sid, _version,  // BaseSlave
            _id, _root, _path, _initTime, _expireTime, _target, _records,  // Certificate
            _durationConfig, _config, _price, _reserved, _inZeroAuction, _needZeroAuction, _auctionRoot, _zeroAuction  // Domain
        );
    }

}
