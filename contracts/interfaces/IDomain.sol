pragma ton-solidity >= 0.61.2;

import "../structures/Configs.sol";


interface IDomain {

    function onDeployRetry(TvmCell code, TvmCell params) external functionID(0x4A2E4FD6);
    function getConfig() external view responsible returns (DomainConfig config);
    function getPrices() external view responsible returns (uint128 defaultPrice, uint128 auctionPrice);
    function getFlags() external view responsible returns (bool inZeroAuction, bool needZeroAuction, bool reserved);

    function startZeroAuction() external;
    function onZeroAuctionFinished() external;

    function expectedRenewAmount(uint32 newExpireTime) external view responsible returns (uint128 amount);
    function renew(uint128 amount, address sender) external;
    function unreserved(address owner, uint128 price, uint32 expireTime, bool needZeroAuction) external;
    function acceptUpgrade(uint16 version, DomainConfig config, TvmCell code) external;

}
