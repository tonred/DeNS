pragma ever-solidity ^0.63.0;


struct RootConfig {
    uint32 maxNameLength;
    uint32 maxPathLength;
    uint32 minDuration;
    uint32 maxDuration;         // also used for DomainConfig
    uint128 graceFinePercent;   // used only for DomainConfig
    uint128 startZeroAuctionFee;
}

struct AuctionConfig {
    address auctionRoot;
    address tokenRoot;
    uint32 duration;
}

struct PriceConfig {
    uint128 longPrice;
    uint128[] shortPrices;  // set 0 for NOT_FOR_SALE name lengths
    uint128 onlyLettersFeePercent;
    uint32 needZeroAuctionLength;
}

struct DurationConfig {
    uint32 startZeroAuction;
    uint32 expiring;
    uint32 grace;
}

struct DomainConfig {
    uint32 maxDuration;
    uint128 graceFinePercent;
}
