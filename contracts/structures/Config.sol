pragma ton-solidity >= 0.61.2;


struct Config {

    address token;
    uint32 maxNameLength;
    uint32 minDuration;
    uint32 maxDuration;

    uint32 startZeroAuctionTimeRange;
    uint32 expiringTimeRange;
    uint32 graceTimeRange;

    // todo price values
    uint128 price3;
    uint128 price4;
    uint128 price5;
    uint128 priceN;

    uint128 graceFinePercent;
    uint128 expiredFinePercent;

}