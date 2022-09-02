pragma ton-solidity >= 0.61.2;


struct RootConfig {
    uint32 maxNameLength;
    uint32 maxPathLength;
    uint32 minDuration;
    uint32 maxDuration;
}

struct PriceConfig {
    // todo price values
    uint128 price3;
    uint128 price4;
    uint128 price5;
    uint128 priceN;
}

struct DomainConfig {
    uint32 maxDuration;
    uint128 graceFinePercent;
}

struct DurationConfig {
    uint32 startZeroAuction;
    uint32 expiring;
    uint32 grace;
}
