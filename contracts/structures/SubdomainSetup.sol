pragma ton-solidity >= 0.61.2;


struct SubdomainSetup {
    address owner;
    uint32 expireTime;
    address parent;
    bool renewable;
    address callbackTo;
}
