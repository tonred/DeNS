pragma ton-solidity >= 0.61.2;

import "../structures/Configs.sol";


interface ISubdomain {
    function renew(uint32 expireTime) external;
    function acceptUpgrade(uint16 version, TimeRangeConfig config, TvmCell code) external;
}
