pragma ever-solidity ^0.63.0;

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
        PriceConfig priceConfig,
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
        priceConfig,
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
