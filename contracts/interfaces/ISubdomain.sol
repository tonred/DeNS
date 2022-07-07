pragma ton-solidity >= 0.61.2;


interface ISubdomain {
    function prolong(uint32 expireTime) external;
}
