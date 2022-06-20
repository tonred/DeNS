pragma ton-solidity >= 0.57.3;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

//import "./interfaces/IUpgradable.sol";
//import "./utils/ErrorCodes.sol";
//import "./utils/Gas.sol";
//import "./utils/TransferUtils.sol";
//
//import "@broxus/contracts/contracts/utils/CheckPubKey.sol";
//import "@broxus/contracts/contracts/utils/RandomNonce.sol";


contract Storage is Addressable {

    event NewDomainCode(uint16 version);
    event NewSubdomainCode(uint16 version);


    TvmCell public _domainCode;
    uint16 public _domainVersion;

    TvmCell public _subdomainCode;
    uint16 public _subdomainVersion;

    TvmCell public _nftCode;
    uint16 public _nftVersion;


    constructor(address root, TvmCell platformCode) public {
        _root = root;
        _platformCode = platformCode;
    }


    function getDomain() public responsible returns (TvmCell code, uint16 version) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_domainCode, _domainVersion);
    }

    function getSubdomain() public responsible returns (TvmCell code, uint16 version) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_subdomainCode, _subdomainVersion);
    }


    function setDomainCode(TvmCell domainCode) public onlyRoot cashBack {
        _domainCode = domainCode;
        _domainVersion++;
        emit NewDomainCode(_subdomainVersion);
    }

    function setSubdomainCode(TvmCell subdomainCode) public onlyRoot cashBack {
        _subdomainCode = subdomainCode;
        _subdomainVersion++;
        emit NewSubdomainCode(_subdomainVersion);
    }

    function withdraw(uint128 value, address recipient) public onlyRoot {
        recipient.transfer({value: value, flag: MsgFlag.REMAINING_GAS, bounce: false});
    }


    function deployDomain(string path, TvmCell params, address callback) public onlyRoot {
        _deployCertificate(path, params, _domainCode, callback);
    }

    function deploySubdomain(string path, TvmCell params, address callback, string parent) public onlyCertificate(parent) {
        _deployCertificate(path, params, _subdomainCode, callback);
    }

    function deployNft(string path) public responsible onlyCertificate(path) returns (address nft) {
        nft = _deployNft(path, initialParams, _subdomainCode, callback);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} nft;
    }

    function _deployCertificate(string path, TvmCell params, TvmCell code, address callback) private {
        _reserve();
        TvmCell stateInit = _buildCertificateStateInit(path);
        address certificate = new Platform{
            stateInit: stateInit,
            value: Gas.CERTIFICATE_DEPLOY_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: true
        }(code, params, address(0));
        IUser(callback).onDeploy{value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false}(certificate);
    }

    function _deployNft(string path, TvmCell initialParams, TvmCell code, address callback) private {
        _reserve();
        TvmCell stateInit = _buildCertificateStateInit(path);
        address certificate = new Platform{
            stateInit: stateInit,
            value: Gas.CERTIFICATE_DEPLOY_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES,
            bounce: true
        }(code, initialParams, address(0));
        IUser(callback).onDeploy{value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false}(certificate);
    }


    // todo update

}
