pragma ton-solidity >= 0.61.2;

import "../structures/Configs.sol";


interface ISubdomain {
    function onDeployRetry(TvmCell code, TvmCell params) external functionID(0x4A2E4FD6);
    function getConfig() external view responsible returns (TimeRangeConfig config);
    function requestRenew() external view;
    function renew(uint32 expireTime) external;
    function acceptUpgrade(uint16 version, TimeRangeConfig config, TvmCell code) external;
}
