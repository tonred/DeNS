pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./interfaces/IUpgradable.sol";
import "./utils/ErrorCodes.sol";
import "./utils/Gas.sol";
import "./utils/TransferUtils.sol";

import "@broxus/contracts/contracts/utils/CheckPubKey.sol";
import "@broxus/contracts/contracts/utils/RandomNonce.sol";


contract Root is Certificate, IUpgradable, TransferUtils, CheckPubKey, RandomNonce {

    uint128 _targetBalance;

    constructor(address owner, TvmCell platformCode, uint128 targetBalance) public checkPubKey {
        tvm.accept();
        _name = "/";
        _parent = address(0);
        _owner = owner;
        _platformCode = platformCode;
        _targetBalance = targetBalance;
    }


    function createTLD(string name, bool check, TvmCell initialParams, TvmCell code) public onlyOwner cashBack {
        if (check) {
            require(checkName(name), 69);
        }
        address tld = _register(name, initialParams, code);
        emit NewTLD(tld, name);
    }

    function forceTakeAway(address certificate, address owner, string reason) public onlyOwner {
        require(certificate != address(this), 69);
        emit TakeAway(certificate, owner, reason);
        Certificate(certificate).takeAway{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: true
        }(owner);
    }

    function resolve(string name) public responsible returns (address) {
        uint from = 0;
        address current = address(this);
        for (uint i = 0; i < name.byteLength(); i++) {
            // todo ask1
            if (name.substr(i, 1) == "/") {
                string nextName = name.substr(from, i - from);
                current = _certificateAddress(nextName, current);
                from = i + 1;
            }
        }
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} current;
    }

    function withdraw() public {
        tvm.rawReserve(_targetBalance, 2);
        _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }

}
