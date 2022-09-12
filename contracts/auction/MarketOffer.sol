pragma ever-solidity ^0.63.0;


struct MarketOffer {
    address collection;
    address nftOwner;
    address nft;
    address offer;
    uint128 price;
    uint128 auctionDuration;
    uint64 deployNonce;
}
