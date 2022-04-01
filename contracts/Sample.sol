pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IUpgradable.sol";
import "./utils/ErrorCodes.sol";
import "./utils/Gas.sol";
import "./utils/TransferUtils.sol";

import "@broxus/contracts/contracts/access/InternalOwner.sol";
import "@broxus/contracts/contracts/platform/Platform.sol";
import "@broxus/contracts/contracts/utils/CheckPubKey.sol";
import "@broxus/contracts/contracts/utils/RandomNonce.sol";


contract Sample is IUpgradable, TransferUtils, InternalOwner, CheckPubKey, RandomNonce {

    constructor(address owner) public checkPubKey {
        tvm.accept();
        setOwnership(owner);
   }

}
