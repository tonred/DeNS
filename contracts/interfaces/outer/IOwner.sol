pragma ton-solidity >= 0.61.2;


interface IOwner {
    function onMint(uint256 id, address nft, address owner, address manager, address creator) external;
    function onBurn(uint256 id, address nft, address owner, address manager) external;
//    // todo down methods where
//    function onProlong(string path, uint32 expireTime) external;
    function onUnresevre(string path, uint32 expireTime) external;
}
