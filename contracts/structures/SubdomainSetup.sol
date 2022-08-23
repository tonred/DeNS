pragma ton-solidity >= 0.61.2;


struct SubdomainSetup {
    address owner;
    address creator;
    uint32 expireTime;
    address parent;
    bool renewable;
}
