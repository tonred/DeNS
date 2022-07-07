pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/NFTCertificate.sol";
import "./interfaces/ICertificate.sol";
import "./structures/Configs.sol";


contract Subdomain is NFTCertificate, ISubdomain {

    event Prolonged(uint32 time, uint32 newExpireTime);

    address public _domain;
    SubdomainConfig public _config;


    modifier onlyDomain() {
        require(msg.sender == _domain, 69);
        _;
    }

    function _init(TvmCell params) internal override {
        (_version, _config, _owner, _expireTime, _indexCode) =
            abi.decode(params, (uint16, SubdomainConfig, address, uint32, TvmCell));
        _initTime = now;
        _initNFT(_owner, _owner, _indexCode);
    }


    function requestProlong() public cashBack {
        ICertificate(_domain).prolongSubdomain{
            value: Gas.PROLONG_SUBDOMAIN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: true
        }(address(this));
    }

    function prolong(uint32 expireTime) public override onlyDomain {
        _reserve();
        _expireTime = expireTime;
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


    function requestUpgrade() public override minValue(Gas.REQUEST_UPGRADE_DOMAIN_VALUE) {
        IRoot(_root).requestSubdomainUpgrade{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(_path, _version);
    }

    function acceptUpgrade(uint16 version, TvmCell code, SubdomainConfig config) public onlyRoot {
        if (version == _version) {
            _owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false});
            return;
        }
        _upgrade(version, code, config);
    }

    function _upgrade(uint16 version, TvmCell code, SubdomainConfig config) private {
//        emit CodeUpgraded(_version, version);
        _version = version;
        _config = config;
        TvmCell data = abi.encode("xxx");  // todo values
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(data);
    }


    onBounce(TvmSlice body) external {
        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(prolongSubdomain)) {
            // parent domain is not exists (this is possible only if it is expired)
            _destroy();
        }
    }

}
