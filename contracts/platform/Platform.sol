pragma ton-solidity >= 0.39.0;

import "../libraries/MsgFlag.sol";


contract Platform {

    address static _root;
    address static _storage;
    uint8 static _platformType;
    TvmCell static _initialData;
    TvmCell static _platformCode;


    constructor(TvmCell code, TvmCell params) public {  // todo functionID()
        if (msg.sender == _storage) {
            _initialize(code, params);
        } else {
            msg.sender.transfer({
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO,
                bounce: false
            });
        }
    }

    function _initialize(TvmCell code, TvmCell params) private {


        TvmBuilder builder;

        builder.store(root);
        builder.store(platformType);
        builder.store(sendGasTo);

        builder.store(platformCode); // ref 1
        builder.store(initialData);  // ref 2
        builder.store(params);       // ref 3

        tvm.setcode(code);
        tvm.setCurrentCode(code);

        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell data) private {}
}
