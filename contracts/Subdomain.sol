pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/NFTCertificate.sol";


contract Subdomain is ISubdomain, NFTCertificate {

    event Renewed(uint32 time, uint32 newExpireTime);

    DurationConfig public _durationConfig;
    address public _parent;
    bool public _renewable;


    modifier onlyParent() {
        require(msg.sender == _parent, 69);
        _;
    }

    modifier onlyRenewable() {
        require(_renewable, 69);
        _;
    }


    function onDeployRetry(TvmCell /*code*/, TvmCell params) public functionID(0x4A2E4FD6) override onlyRoot {
        (/*path*/, /*durationConfig*/, SubdomainSetup setup, /*indexCode*/)
            = abi.decode(params, (string, DurationConfig, SubdomainSetup, TvmCell));
        if (_status() == CertificateStatus.EXPIRED) {
            _destroy();
        }
        // todo check how it works after destroy
        IOwner(setup.creator).onCreateSubdomainError{
            value: 0,
            flag: MsgFlag.REMAINING_GAS,
            bounce: false
        }(_path, TransferBackReason.ALREADY_EXIST);
    }

    function _init(TvmCell params) internal override {
        _reserve();
        SubdomainSetup setup;
        address creator;
        (_path, _durationConfig, setup, _indexCode) =
            abi.decode(params, (string, DurationConfig, SubdomainSetup, TvmCell));
        (_owner, creator, _expireTime, _parent, _renewable) = setup.unpack();
        _initTime = now;
        IOwner(creator).onSubdomainCreated{
            value: Gas.RENEW_SUBDOMAIN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(_path, _owner);
        _initNFT(_owner, _owner, _indexCode, creator);
    }


    function getDurationConfig() public view responsible override returns (DurationConfig durationConfig) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _durationConfig;
    }

    function requestRenew() public view override onlyRenewable cashBack {
        Certificate(_parent).renewSubdomain{
            value: Gas.RENEW_SUBDOMAIN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(address(this));
    }

    function renew(uint32 expireTime) public override onlyParent onlyRenewable {
        _reserve();
        _expireTime = expireTime;
        emit Renewed(now, _expireTime);
        _owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
    }


    function _status() internal view override returns (CertificateStatus) {
        int64 left = int64(_expireTime) - now;
        if (left < -_durationConfig.grace) {
            return CertificateStatus.EXPIRED;
        } else if (left < 0) {
            return CertificateStatus.GRACE;
        } else if (left < _durationConfig.expiring) {
            return CertificateStatus.EXPIRING;
        } else {
            return CertificateStatus.COMMON;
        }
    }

    function _targetBalance() internal view inline override returns (uint128) {
        return Gas.SUBDOMAIN_TARGET_BALANCE;
    }


    function _encodeContractData() internal override returns (TvmCell) {
        return abi.encode("xxx");  // todo values
    }

}
