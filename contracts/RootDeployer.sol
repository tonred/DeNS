pragma ton -solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./structures/Configs.sol";
import "./structures/SubdomainSetup.sol";
import "./Root.sol";

import "@broxus/contracts/contracts/utils/CheckPubKey.sol";

contract RootDeployer is CheckPubKey {
    uint static _randomNonce;

    TvmCell public _platformCode;
    TvmCell public _rootCode;

    TvmCell public _domainCode;
    TvmCell public _subdomainCode;
    TvmCell public _indexBasisCode;
    TvmCell public _indexCode;


    constructor(TvmCell platformCode) public checkPubKey {
        tvm.accept();
        _platformCode = platformCode;
    }

    function setRootCode(TvmCell rootCode) public checkPubKey {
        tvm.accept();
        _rootCode = rootCode;
    }

    function setDomainCode(TvmCell domainCode) public checkPubKey {
        tvm.accept();
        _domainCode = domainCode;
    }

    function setSubdomainCode(TvmCell subdomainCode) public checkPubKey {
        tvm.accept();
        _subdomainCode = subdomainCode;
    }

    function setIndexBasisCode(TvmCell indexBasisCode) public checkPubKey {
        tvm.accept();
        _indexBasisCode = indexBasisCode;
    }

    function setIndexCode(TvmCell indexCode) public checkPubKey {
        tvm.accept();
        _indexCode = indexCode;
    }

    function NewRoot(
        uint randomNonce,
        string tld,
        string json,
//        address token,
        address dao,
        address admin,
        RootConfig config,
        AuctionConfig auctionConfig,
        DurationConfig durationConfig
    ) public view checkPubKey returns (address){
        tvm.accept();
        TvmCell stateInit = tvm.buildStateInit({
            contr: Root,
            varInit: {
                _randomNonce: randomNonce,
                _tld: tld
            },
            code: _rootCode
        });
        return new Root{
            stateInit: stateInit,
            value: 1 ton,
            flag: 1,
            bounce: true
        }(
            _domainCode,
            _subdomainCode,
            _indexBasisCode,
            _indexCode,
            json,
            _platformCode,
//            token,
            dao,
            admin,
            config,
            auctionConfig,
            durationConfig
        );
    }
}
