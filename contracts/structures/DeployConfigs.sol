pragma ton-solidity >= 0.61.2;

import "./Configs.sol";


struct DomainDeployConfig {
    uint16 version;
    DomainConfig config;
    TvmCell code;
}

struct SubdomainDeployConfig {
    uint16 version;
    SubdomainConfig config;
    TvmCell code;
}
