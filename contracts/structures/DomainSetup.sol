pragma ever-solidity ^0.63.0;


struct DomainSetup {
    address owner;
    uint128 price;
    bool reserved;
    bool needZeroAuction;
    uint32 expireTime;
    uint128 amount;
}
