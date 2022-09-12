pragma ever-solidity ^0.63.0;

import "./MarketOffer.sol";


interface IAuctionRootCallback {
    function auctionTip3DeployedCallback(address offerAddress, MarketOffer offerInfo) external;
    // function auctionTip3DeployedDeclined(address nftOwner, address dataAddress) external;
}
