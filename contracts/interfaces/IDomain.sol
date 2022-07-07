pragma ton-solidity >= 0.61.2;

import "../structures/Configs.sol";


interface IDomain {
    function prolong(uint128 amount, address sender) external;
    function acceptUpgrade(uint16 version, DomainConfig config, TvmCell code) external;
}
