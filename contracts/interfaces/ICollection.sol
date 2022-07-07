pragma ton-solidity >= 0.61.2;


interface ICollection {
    function onMint(uint256 id, address owner, address manager) external;
    function onBurn(uint256 id, address owner, address manager) external;
}
