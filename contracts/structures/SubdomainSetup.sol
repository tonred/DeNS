pragma ever-solidity ^0.63.0;


struct SubdomainSetup {
    address owner;
    address creator;
    uint32 expireTime;
    address parent;
    bool renewable;
}
