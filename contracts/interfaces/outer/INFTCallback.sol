pragma ton-solidity >= 0.61.2;


interface INFTCallback {
    function callback(uint256 id, address owner, address manager, address collection, TvmCell payload) external;
}
