pragma ton-solidity >= 0.61.2;

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
    event ZeroAuctionFinished(address winner);
    event Renewed(uint32 time, uint32 duration, uint32 newExpireTime);


    DomainConfig public _config;
    DurationConfig public _durationConfig;

    uint128 public _price;
    bool public _reserved;

    bool public _inZeroAuction;
    bool public _needZeroAuction;
    address public _zeroAuction;


    // 0x4A2E4FD6 is a Platform constructor functionID
    function onDeployRetry(TvmCell /*code*/, TvmCell params) public functionID(0x4A2E4FD6) override onlyRoot {
        (/*path*/, /*durationConfig*/, /*config*/, DomainSetup setup, /*indexCode*/)
            = abi.decode(params, (string, DurationConfig, DomainConfig, DomainSetup, TvmCell));
        if (setup.reserved) {
            _root.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
            return;
        }
        IRoot(_root).onDomainDeployRetry{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(_path, setup.amount, setup.owner);
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
        (_owner, _price, _reserved, _needZeroAuction, _expireTime, /*amount*/) = setup.unpack();
        _zeroAuction = address.makeAddrNone();
        _initNFT(_owner, _owner, indexCode, _owner);
    }


    function getConfig() public view responsible override returns (DomainConfig config) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _config;
    }

    function getDurationConfig() public view responsible override returns (DurationConfig durationConfig) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _durationConfig;
    }

    function getPrice() public view responsible override returns (uint128 price) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _price;
    }

    function getFlags() public view responsible override returns (bool inZeroAuction, bool needZeroAuction, bool reserved) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_inZeroAuction, _needZeroAuction, _reserved);
    }

    function getZeroAuction() public view responsible override returns (optional(address) zeroAuction) {
        if (!_zeroAuction.isNone()) {
            zeroAuction.set(_zeroAuction);
        }
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} zeroAuction;
    }


    function requestZeroAuction() public view override onStatus(CertificateStatus.NEW) cashBack {
        IRoot(_root).startZeroAuction{
            value: Gas.START_ZERO_AUCTION_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_path, msg.sender);
    }

    function startZeroAuction(AuctionConfig config, address remainingGasTo) public override onlyRoot onStatus(CertificateStatus.NEW) {
        _inZeroAuction = true;
        _owner = _manager = _root;  // in order to integrate with auction root
        mapping(address => CallbackParams) callbacks;
        TvmCell payload = _buildAuctionPayload(config);
        callbacks[config.auctionRoot] = CallbackParams(Gas.CREATE_AUCTION_VALUE, payload);
        changeManager(config.auctionRoot, remainingGasTo, callbacks);
    }

    function onZeroAuctionStarted(address zeroAuction) public override onlyRoot {
        emit ZeroAuctionStarted(zeroAuction);
        _zeroAuction = zeroAuction;
    }

    function onZeroAuctionFinished() public override onStatus(CertificateStatus.IN_ZERO_AUCTION) {
        // todo onZeroAuctionFinished
//        require(msg.sender == _auction, 69);

//        emit ZeroAuctionFinished(winner);
//        _auction = address.makeAddrNone();
        _inZeroAuction = false;
        _needZeroAuction = false;
    }

    function expectedRenewAmount(uint32 newExpireTime) public view responsible override returns (uint128 amount) {
        CertificateStatus status = _status();
        if (newExpireTime <= _expireTime || newExpireTime > now + _config.maxDuration ||
            status == CertificateStatus.RESERVED || status == CertificateStatus.EXPIRED) {
            return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} 0;
        }
        uint32 increase = newExpireTime - _expireTime;
        uint128 price = _calcRenewPrice(status);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} Converter.toAmount(increase, price);
    }

    function renew(uint128 amount, address sender) public override onlyRoot {
        _reserve();
        CertificateStatus status = _status();
        if (sender != _owner || now + _config.maxDuration <= _expireTime ||
            status == CertificateStatus.RESERVED || status == CertificateStatus.EXPIRED) {
            // wrong sender OR already renewed for max period OR reserved OR expired
            IRoot(_root).onDomainRenewReturn{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false
            }(_path, amount, sender);
            return;
        }

        uint128 price = _calcRenewPrice(status);
        uint32 maxIncrease = now + _config.maxDuration - _expireTime;
        uint128 maxAmount = Converter.toAmount(maxIncrease, price);
        uint128 returnAmount = (maxAmount < amount) ? (amount - maxAmount) : 0;
        amount = math.max(amount, maxAmount);

        uint32 duration = Converter.toDuration(amount, price);
        _expireTime += duration;
        emit Renewed(now, duration, _expireTime);

        if (returnAmount > 0) {
            IRoot(_root).onDomainRenewReturn{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false
            }(_path, returnAmount, sender);
        } else {
            IOwner(_owner).onRenewed{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false
            }(_path, _expireTime);
        }
    }

    function unreserve(address owner, uint128 price, uint32 expireTime, bool needZeroAuction) public override onlyRoot {
        _updateIndexes(_owner, owner, _owner);
        _owner = owner;
        _price = price;
        _needZeroAuction = needZeroAuction;
        _reserved = false;
        _initTime = now;
        _expireTime = expireTime;
        IOwner(_owner).onUnreserved{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
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

    function _calcRenewPrice(CertificateStatus status) private view inline returns (uint128) {
        uint128 price = _price;
        if (status == CertificateStatus.GRACE) {
            price += math.muldiv(_config.graceFinePercent, price, Constants.PERCENT_DENOMINATOR);
        }
        return price;
    }

    function _buildAuctionPayload(AuctionConfig config) private view inline returns (TvmCell) {
        TvmBuilder builder;
        builder.store(config.tokenRoot, _price, now, config.duration);
        return builder.toCell();
    }

    function _targetBalance() internal view inline override returns (uint128) {
        return Gas.DOMAIN_TARGET_BALANCE;
    }


    function _encodeContractData() internal override returns (TvmCell) {
        return abi.encode("xxx");  // todo values
    }

}
