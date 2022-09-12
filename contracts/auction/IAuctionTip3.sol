pragma ever-solidity ^0.63.0;


interface IAuctionTip3 {

    function onTokenWallet(address value) external;
    function getTypeContract() external;

    function onAcceptTokensTransfer(
        address token_root,				
        uint128 amount,					
        address sender,			 
        address /*sender_wallet*/,			
        address original_gas_to,		
        TvmCell payload					
    ) external;

    function processBid(
        uint32 _callbackId,
        address _newBidSender,
        uint128 _bid,
        address original_gas_to
    ) external;

    // Calls `transfer` in NFT contract
    function finishAuction(address sendGasTo) external;

    function buildPlaceBidPayload(uint32 callbackId, address buyer) external;
    function getInfo() external;

    function upgrade(
        TvmCell newCode,
        uint32 newVersion,
        address sendGasTo
    ) external;

}
