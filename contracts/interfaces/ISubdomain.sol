pragma ever-solidity ^0.63.0;

import "../structures/Configs.sol";


interface ISubdomain {

    function onDeployRetry(TvmCell code, TvmCell params) external functionID(0x4A2E4FD6);
    function getDurationConfig() external view responsible returns (DurationConfig durationConfig);
    function requestRenew() external view;
    function renew(uint32 expireTime) external;

}
