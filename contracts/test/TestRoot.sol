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
        address token,
        address dao,
        address admin,
        RootConfig config,
        DomainConfig domainConfig,
        DurationConfig durationConfig
    ) public Root(
        domainCode,
        subdomainCode,
        indexBasisCode,
        indexCode,
        json,
        platformCode,
        token,
        dao,
        admin,
        config,
        domainConfig,
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
