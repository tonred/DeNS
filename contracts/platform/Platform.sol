pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "@broxus/contracts/contracts/platform/Platform.sol";


contract RPlatform is Platform {
    constructor(TvmCell code, TvmCell params, address remainingGasTo) public Platform(code, params, remainingGasTo) functionID(0x3f61459c) {}
}
