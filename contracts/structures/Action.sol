pragma ton-solidity >= 0.61.2;


// todo import from OverDao
struct Action {
    address target;
    uint128 value;
    TvmCell payload;
    TvmCell abi;
}
