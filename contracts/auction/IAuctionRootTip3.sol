pragma ever-solidity ^0.63.0;


interface IAuctionRootTip3 {

    function changeDeploymentFee(uint128 _value) external;
    function changeMarketFee(uint8 _value, uint8 _decimals) external;
    function getTypeContract() external;

    // Call it to start new auction
    function onNftChangeManager(
        uint256 /*id*/,
        address nftOwner,
        address /*oldManager*/,
        address newManager,
        address collection,
        address sendGasTo,
        TvmCell payload
    ) external;

    function getOfferAddress(
        address _nft,
        uint128 _price,
        uint64 _nonce
    ) external;

    function buildAuctionCreationPayload(
        address _paymentTokenRoot,
        uint128 _price,
        uint64 _auctionStartTime,
        uint64 _auctionDuration
    ) external;

    function RequestUpgradeAuction(
        address _nft,
        uint128 _price,
        uint64 _nonce,
        address sendGasTo
    ) external;

    function upgradeOfferCode(TvmCell newCode) external;

    function upgrade(
        TvmCell newCode,
        uint32 newVersion,
        address sendGasTo
    ) external;

}
