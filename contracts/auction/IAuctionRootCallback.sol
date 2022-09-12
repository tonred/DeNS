pragma ever-solidity >= 0.62.0;  // todo all to one standard

import "./MarketOffer.sol";


interface IAuctionRootCallback {
    function auctionTip3DeployedCallback(address offerAddress, MarketOffer offerInfo) external;
    // function auctionTip3DeployedDeclined(address nftOwner, address dataAddress) external;
}
