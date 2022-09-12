pragma ever-solidity ^0.63.0;

import "../structures/Configs.sol";


interface IDomain {

    function onDeployRetry(TvmCell code, TvmCell params) external functionID(0x4A2E4FD6);
    function getConfig() external view responsible returns (DomainConfig config);
    function getDurationConfig() external view responsible returns (DurationConfig durationConfig);
    function getPrice() external view responsible returns (uint128 price);
    function getFlags() external view responsible returns (bool inZeroAuction, bool needZeroAuction, bool reserved);
    function getZeroAuction() external view responsible returns (optional(address) zeroAuction);

    function requestZeroAuction() external view;
    function startZeroAuction(AuctionConfig config, address remainingGasTo) external;

    function expectedRenewAmount(uint32 newExpireTime) external view responsible returns (uint128 amount);
    function renew(uint128 amount, address sender) external;
    function unreserve(address owner, uint128 price, uint32 expireTime, bool needZeroAuction) external;

}
