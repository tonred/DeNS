pragma ton-solidity >= 0.61.2;


struct DomainSetup {
    address owner;
    uint128 price;
    bool needZeroAuction;
    bool reserved;
    uint32 expireTime;
    uint128 amount;
}
