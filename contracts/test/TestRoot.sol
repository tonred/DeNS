pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../Root.sol";


contract TestRoot is Root {

    constructor(
        TvmCell domainCode,
        TvmCell subdomainCode,
        TvmCell indexBasisCode,
        TvmCell indexCode,
        string json,
        TvmCell platformCode,
        address dao,
        address admin,
        RootConfig config,
        AuctionConfig auctionConfig,
        DurationConfig durationConfig
    ) public Root(
        domainCode,
        subdomainCode,
        indexBasisCode,
        indexCode,
        json,
        platformCode,
        dao,
        admin,
        config,
        auctionConfig,
        durationConfig
    ) {
        tvm.accept();
    }

    function onAcceptTokensTransferTest(
        uint128 amount,
        address sender,
        TvmCell payload
    ) public {
        _wallet = msg.sender;  // in order to skip further checks
        address zero = address(0);
        onAcceptTokensTransfer(zero, amount, sender, zero, zero, payload);
    }

}
