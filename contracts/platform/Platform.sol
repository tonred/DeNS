pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "@broxus/contracts/contracts/platform/Platform.sol";


contract RPlatform is Platform {
    // todo use custom Platform (root -> sender)
    constructor(TvmCell code, TvmCell params, address remainingGasTo) public Platform(code, params, remainingGasTo) {}
}
