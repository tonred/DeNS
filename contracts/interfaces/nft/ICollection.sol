pragma ton-solidity >= 0.61.2;


interface ICollection {

    function totalSupply() external view responsible returns (uint128 count);
    function nftCode() external view responsible returns (TvmCell code);
    function nftCodeHash() external view responsible returns (uint256 codeHash);
    function nftAddress(uint256 id) external view responsible returns (address nft);
    function nftAddressByName(string name) external view responsible returns (address nft);

    function mint(string name, address owner, uint32 expireTime, uint32 expiringTimeRange) external;
    function onNftBurn(uint256 id, address owner, address manager) external;

}
