pragma ton-solidity >= 0.61.2;


interface ICollection {
    function nftAddressByName(string name) external view responsible returns (address nft);
    function mint(string name, address owner, uint32 expireTime, uint32 expiringTimeRange) external;
    function onMint(uint256 id, address owner, address manager) external;
    function onBurn(uint256 id, address owner, address manager) external;
}
