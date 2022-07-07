pragma ton-solidity >= 0.61.2;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;


// todo
struct DomainDeployConfig {
    uint16 version;
    DomainConfig config;
    TvmCell code;
}


contract CodeStorage is ICodeStorage, Addressable, RandomNonce {

    DomainDeployConfig public _domainDeployConfig;
    SubdomainDeployConfig public _subdomainDeployConfig;


    modifier onlyCertificate(string path) {
        address certificate = _certificateAddress(path);
        require(msg.sender == certificate, 69);
        _;
    }

    constructor(
        address dao,
        address collection,
        DomainDeployConfig domainDeployConfig,
        SubdomainDeployConfig subdomainDeployConfig
    ) public checkPubKey {
        tvm.accept();
        _dao = dao;
        _collection = collection;
        _domainDeployConfig = domainDeployConfig;
        _subdomainDeployConfig = subdomainDeployConfig;
    }


    // todo getters

    function updateDomainDeployConfig(DomainConfig config, TvmCell code) public override onlyDao cashBack {
        uint16 version = _domainDeployConfig.version + 1;
        _domainDeployConfig = DomainDeployConfig(version, config, code);
        emit DomainDeployConfigUpgraded(version);
        // todo require checks for values that exists in domain and subdomain
    }

    function updateSubdomainDeployConfig(SubdomainConfig config, TvmCell code) public override onlyDao cashBack {
        uint16 version = _subdomainDeployConfig.version + 1;
        _subdomainDeployConfig = SubdomainDeployConfig(version, config, code);
        emit SubdomainDeployConfigUpgraded(version);
        // todo require checks for values that exists in domain and subdomain
    }


    function registerDomain(string path, DomainSetup setup) public onlyRoot {
        address nft = _nftAddressByPath(_collection, path);
        (uint16 version, DomainConfig config, TvmCell code) = _domainDeployConfig.unpack();
        TvmCell params = abi.encode(version, config, nft, setup);
        _register(path, setup.owner, config.expireTime, code, params);
    }

    function registerSubdomain(string path, address owner, uint32 expireTime) public onlyCertificate(path) {
        address nft = _nftAddressByPath(_collection, path);
        (uint16 version, SubdomainConfig config, TvmCell code) = _subdomainDeployConfig.unpack();
        TvmCell params = abi.encode(version, config, nft, owner, expireTime);
        _register(path, owner, expireTime, code, params);
    }

    function _register(string path, address owner, uint32 expireTime, TvmCell code, TvmCell params) private view {
        address nft = _nftAddressByPath(_collection, path);
        _mintNft(path, owner, expireTime);
        _deployCertificate(path, code, params);
    }

    function _mintNft(string path, address owner, uint32 expireTime) private view {
        ICollection(_collection).mint{
            value: Gas.MINT_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(path, owner, expireTime, _subdomainDeployConfig.config.expiringTimeRange);
    }

    function _deployCertificate(string path, uint128 value, TvmCell code, TvmCell params) private view {
        TvmCell stateInit = buildCertificateStateInit(path);
        new Platform{
            stateInit: stateInit,
            value: value,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: false
        }(code, params, address(0));
    }


    function upgradeDomain(address domain) public override {
        if (version != _domainDeployConfig.version) {
            (uint16 version, DomainConfig config, TvmCell code) = _domainDeployConfig.unpack();
            IDomain(domain).upgrade{
                value: Gas.UPGRADE_DOMAIN_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES,
                bounce: false
            }(version, config, code);
        }
    }

    function upgradeSubdomain(address subdomain) public override {
        if (version != _subdomainDeployConfig.version) {
            (uint16 version, SubdomainConfig config, TvmCell code) = _subdomainDeployConfig.unpack();
            ISubdomain(subdomain).upgrade{
                value: Gas.UPGRADE_SUBDOMAIN_VALUE,
                flag: MsgFlag.SENDER_PAYS_FEES,
                bounce: false
            }(version, config, code);
        }
    }

}
