pragma ton-solidity >= 0.61.2;


interface IDomain {
    function prolong(uint128 amount, address sender) external;
}
