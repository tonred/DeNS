pragma ton-solidity >= 0.57.3;

import "@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract TransferUtils {

    modifier cashBack() {
        _reserve();
        _;
        msg.sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

    function _reserve() internal view {
        tvm.rawReserve(address(this).balance - msg.value, 2);
    }

}
