pragma ton-solidity >= 0.61.2;


struct RootConfig {
    address token;
    uint32 maxNameLength;
    uint32 minDuration;
    uint32 maxDuration;
    PriceConfig prices;
}

struct PriceConfig {
    // todo price values
    uint128 price3;
    uint128 price4;
    uint128 price5;
    uint128 priceN;
}

struct DomainConfig {
    uint32 maxNameLength;
    // time ranges
    uint32 startZeroAuctionTimeRange;
    uint32 expiringTimeRange;
    uint32 graceTimeRange;
    // fine percents
    uint128 graceFinePercent;
    uint128 expiredFinePercent;
}

struct SubdomainConfig {
    uint32 maxNameLength;
    uint32 expiringTimeRange;
    uint32 graceTimeRange;
}
