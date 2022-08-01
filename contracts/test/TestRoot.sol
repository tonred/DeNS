pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../Root.sol";


contract TestRoot is Root {

    constructor(
        TvmCell nftCode,
        TvmCell indexBasisCode,
        TvmCell indexCode,
        string json,
        TvmCell platformCode,
        address token,
        address dao,
        RootConfig config,
        DomainDeployConfig domainDeployConfig,
        SubdomainDeployConfig subdomainDeployConfig
    ) public Root(
        nftCode,
        indexBasisCode,
        indexCode,
        json,
        platformCode,
        token,
        dao,
        config,
        domainDeployConfig,
        subdomainDeployConfig
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
