pragma ton-solidity >= 0.61.2;


interface IOwner {  // todo INFTOwner
    function onMint(uint256 id, address nft, address owner, address manager, address creator) external;
    function onBurn(uint256 id, address nft, address owner, address manager) external;
    // todo down methods where
    function onProlong(string name, uint32 expireTime) external;
    function onUnresevre(string name, uint32 expireTime) external;
}
