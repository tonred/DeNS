pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/Certificate.sol";
import "./interfaces/nft/INFT.sol";
import "./interfaces/IDomain.sol";
//import "./interfaces/IRoot.sol";
//import "./structures/DomainSetup.sol";
//import "./utils/Converter.sol";
//import "./utils/Gas.sol";

//import "@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract Domain is IDomain, Certificate {

    event ZeroAuctionStarted();
    event ZeroAuctionFinished();
    event Prolonged(uint32 time, uint32 duration, uint32 newExpireTime);


    uint128 public _defaultPrice;
    uint128 public _auctionPrice;

    bool public _inZeroAuction;
    bool public _needZeroAuction;
    bool public _reserved;


    // 0x3F61459C is Platform constructor functionID
    function onDeployRetry(TvmCell code, TvmCell params, address /*remainingGasTo*/) public functionID(0x3F61459C) onlyRoot {
        (uint16 version, /*nft*/, Config config, DomainSetup setup) = abi.decode(params, (uint16, address, Config, DomainSetup));
        if (_status() == CertificateStatus.EXPIRED) {
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
                }(_path, setup.amount, setup.owner);
            }
        }
    }

    function _init(TvmCell params) internal override {
//        DomainSetup setup;
        (_version, _config, _nft, DomainSetup setup) = abi.decode(params, (uint16, Config, address, DomainSetup));
        (_owner, _defaultPrice, _needZeroAuction, _reserved, _expireTime, /*amount*/) = setup.unpack();
        _currentPrice = _defaultPrice;
        _initTime = now;
    }


    function getPrices() public responsible override returns (uint128 defaultPrice, uint128 auctionPrice) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_defaultPrice, _auctionPrice);
    }

    function getFlags() public responsible override returns (bool inZeroAuction, bool needZeroAuction, bool reserved) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_inZeroAuction, _needZeroAuction, _reserved);
    }


    function startZeroAuction() public override onStatus(CertificateStatus.NEW) minValue(Gas.START_ZERO_AUCTION_VALUE) {
        // todo

        emit ZeroAuctionStarted();
        _inZeroAuction = true;
    }

    function zeroAuctionFinished() public override onStatus(CertificateStatus.IN_ZERO_AUCTION) {
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
        CertificateStatus status = _status();
        if (duration > _config.maxDuration || now + duration <= _expireTime || status == CertificateStatus.RESERVED) {
            return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} 0;
        }
        uint32 increase = now + duration - _expireTime;
        uint128 price = _calcProlongPrice(status);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} Converter.toAmount(increase, price);
    }

    function prolong(uint128 amount, address sender) public override onlyRoot {
        CertificateStatus status = _status();
        if (sender != _owner || now + _config.maxDuration <= _expireTime || status == CertificateStatus.RESERVED) {
            // wrong sender OR already prolonged for max period OR reserved
            IRoot(_root).onProlongReturn{
                value: 0,
                flag: MsgFlag.REMAINING_GAS,
                bounce: false
            }(_path, amount, sender);
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
        _prolongNFT();
        emit Prolonged(now, duration, _expireTime);

        if (returnAmount > 0) {
            IRoot(_root).onProlongReturn{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false
            }(_path, returnAmount, sender);
        } else {
            _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
        }
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


    function _status() internal view override returns (CertificateStatus) {
        int64 passed = int64(now) - _initTime;
        int64 left = int64(_expireTime) - now;
        if (_reserved) {
            return CertificateStatus.RESERVED;
        } else if (_inZeroAuction) {
            return CertificateStatus.IN_ZERO_AUCTION;
        } else if (passed < _config.startZeroAuctionTimeRange && !_needZeroAuction) {
            return CertificateStatus.NEW;
        } else if (left < -_config.graceTimeRange) {
            return CertificateStatus.EXPIRED;
        } else if (left < 0) {
            return CertificateStatus.GRACE;
        } else if (left < _config.expiringTimeRange) {
            return CertificateStatus.EXPIRING;
        } else {
            return CertificateStatus.COMMON;
        }
    }

    function _calcProlongPrice(CertificateStatus status) private view inline returns (uint128) {
        uint128 price = _auctionPrice;  // todo _defaultPrice VS _auctionPrice
        if (status == CertificateStatus.GRACE) {
            price += math.muldiv( _config.graceFinePercent, price, Constants.PERCENT_DENOMINATOR);
        } else if (status == CertificateStatus.EXPIRED) {
           price += math.muldiv( _config.expiredFinePercent, price, Constants.PERCENT_DENOMINATOR);
        }
        return price;
    }


    onBounce(TvmSlice body) external {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(prolongSubdomain)) {
            // subdomain not exists minted
            _owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
        }
    }

}
