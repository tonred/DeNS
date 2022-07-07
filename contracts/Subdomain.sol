pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/Certificate.sol";
import "./interfaces/nft/INFT.sol";
import "./interfaces/IDomain.sol";
//import "./interfaces/IRoot.sol";
//import "./structures/DomainSetup.sol";
//import "./utils/Converter.sol";
//import "./utils/Gas.sol";

//import "@broxus/contracts/contracts/libraries/MsgFlag.sol";


contract Subdomain is ISubdomain, Certificate {

    event Prolonged(uint32 time, uint32 newExpireTime);

    address public _domain;


    modifier onlyDomain() {
        require(msg.sender == _domain, 69);
        _;
    }

    function _init(TvmCell params) internal override {
        (_version, _config, _nft, _owner, _expireTime) =
            abi.decode(params, (uint16, Config, address, address, uint32));
        _initTime = now;
    }


    function requestProlong() public override cashBack {
        IDomain(_domain).prolongSubdomain{
            value: Gas.PROLONG_SUBDOMAIN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: true
        }(address(this));
    }

    function prolong(uint32 expireTime) public override onlyDomain {
        _reserve();
        _expireTime = expireTime;
        _prolongNFT();
        emit Prolonged(now, _expireTime);
        _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }


    function _status() internal view override returns (CertificateStatus) {
        int64 left = int64(_expireTime) - now;
        if (left < -_config.graceTimeRange) {
            return CertificateStatus.EXPIRED;
        } else if (left < 0) {
            return CertificateStatus.GRACE;
        } else if (left < _config.expiringTimeRange) {
            return CertificateStatus.EXPIRING;
        } else {
            return CertificateStatus.COMMON;
        }
    }


    onBounce(TvmSlice body) external {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(prolongSubdomain)) {
            // parent domain is not exists (this is possible only if it is expired)
            _destroy();
        }
    }

}
