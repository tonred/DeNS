pragma ton-solidity >= 0.61.2;


interface INFT {
    function prolong(uint32 expireTime) external;
    function unreserve(address owner, uint32 expireTime) external;
    function burn() external;
}
