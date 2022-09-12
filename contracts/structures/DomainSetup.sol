pragma ton-solidity >= 0.61.2;


struct DomainSetup {
    address owner;
    uint128 price;
    bool reserved;
    bool needZeroAuction;
    uint32 expireTime;
    uint128 amount;
}
