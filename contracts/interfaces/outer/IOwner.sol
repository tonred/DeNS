pragma ton-solidity >= 0.61.2;


interface IOwner {
    function onProlong(string name, uint32 expireTime) external;
    function onUnresevre(string name, uint32 expireTime) external;
}
