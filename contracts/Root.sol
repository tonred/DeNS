pragma ever-solidity ^0.63.0;

pragma AbiHeader time;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./abstract/NFTCertificate.sol";
import "./abstract/Vault.sol";
import "./enums/TransferKind.sol";
import "./interfaces/IDomain.sol";
import "./interfaces/IUpgradable.sol";
import "./utils/Converter.sol";

import "@broxus/contracts/contracts/utils/RandomNonce.sol";
import {BaseMaster, SlaveData} from "versionable/contracts/BaseMaster.sol";


contract Root is IRoot, Collection, Vault, BaseMaster, IUpgradable, RandomNonce {

    event Renewed(string path);
    event ZeroAuctionStarted(string path);
    event Confiscated(string path, string reason, address owner);
    event Reserved(string path, string reason);
    event Unreserved(string path, string reason, address owner);
    event DomainCodeUpgraded(uint16 newVersion);

    string public static _tld;

    address public _dao;
    address public _admin;
    bool public _active;

    RootConfig public _config;
    PriceConfig public _priceConfig;
    AuctionConfig public _auctionConfig;
    DurationConfig public _durationConfig;


    modifier onlyDao() {
        require(msg.sender == _dao, ErrorCodes.IS_NOT_DAO);
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin, ErrorCodes.IS_NOT_ADMIN);
        _;
    }

    modifier onActive() {
        require(_active, ErrorCodes.IS_NOT_ACTIVE);
        _;
    }

    modifier onlyCertificate(string path) {
        address certificate = _certificateAddress(path);
        require(msg.sender == certificate, ErrorCodes.IS_NOT_CERTIFICATE);
        _;
    }

    modifier onlyAuctionRoot() {
        require(msg.sender == _auctionConfig.auctionRoot, ErrorCodes.IS_NOT_AUCTION_ROOT);
        _;
    }


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
    )
        public
        Collection(domainCode, indexBasisCode, indexCode, json, platformCode)
        Vault(auctionConfig.tokenRoot)
    {
        tvm.accept();
        _initVersions([Constants.DOMAIN_SID, Constants.SUBDOMAIN_SID], [domainCode, subdomainCode]);
        _dao = dao;
        _admin = admin;
        _config = config;
        _priceConfig = priceConfig;
        _auctionConfig = auctionConfig;
        _durationConfig = durationConfig;
    }

    function getPath() public view responsible override returns (string path) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _tld;
    }

    function getDetails() public view responsible override returns (string tld, address dao, bool active) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (_tld, _dao, _active);
    }

    function getConfigs() public view responsible override returns (
        RootConfig config, PriceConfig priceConfig, AuctionConfig auctionConfig, DurationConfig durationConfig
    ) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} (
            _config, _priceConfig, _auctionConfig, _durationConfig
        );
    }

    function checkName(string name) public view responsible override returns (bool correct) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _isCorrectName(name);
    }

    function expectedPrice(string name) public view responsible override returns (uint128 price, bool needZeroAuction) {
        // returns 0 for NOT_FOR_SALE name length
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _calcPrice(name);
    }

    function expectedRegisterAmount(string name, uint32 duration) public view responsible override returns (uint128 amount) {
        require(duration >= _config.minDuration && duration <= _config.maxDuration, ErrorCodes.INVALID_DURATION);
        (uint128 price, /*needZeroAuction*/) = _calcPrice(name);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} Converter.toAmount(duration, price);
    }

    function resolve(string path) public view responsible override returns (address certificate) {
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} _certificateAddress(path);
    }

    function expectedCertificateCodeHash(address target, uint16 sid) public view responsible override returns (uint256 codeHash) {
        require(sid == Constants.DOMAIN_SID || sid == Constants.SUBDOMAIN_SID, ErrorCodes.INVALID_SID);
        TvmCell salt = abi.encode(target);
        TvmCell originalCode = _getLatestCode(sid);
        TvmCell code = tvm.setCodeSalt(originalCode, salt);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} tvm.hash(code);
    }


    function buildRegisterPayload(string name) public view responsible override returns (TvmCell payload) {
        payload = _buildTokensTransferPayload(name, TransferKind.REGISTER);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} payload;
    }

    function buildRenewPayload(string name) public view responsible override returns (TvmCell payload) {
        payload = _buildTokensTransferPayload(name, TransferKind.RENEW);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} payload;
    }

    function buildStartZeroAuctionPayload(string name) public view responsible override returns (TvmCell payload) {
        payload = _buildTokensTransferPayload(name, TransferKind.START_ZERO_AUCTION);
        return {value: 0, flag: MsgFlag.REMAINING_GAS, bounce: false} payload;
    }

    function onAcceptTokensTransfer(
        address /*tokenRoot*/,
        uint128 amount,
        address sender,
        address /*senderWallet*/,
        address /*remainingGasTo*/,
        TvmCell payload
    ) public override onlyWallet {
        _reserve();
        _balance += amount;
        if (!_active) {
            _returnTokens(amount, sender, TransferBackReason.IS_NOT_ACTIVE);
            return;
        }

        (TransferKind kind, TvmCell data) = abi.decode(payload, (TransferKind, TvmCell));
        if (kind == TransferKind.REGISTER) {
            string name = abi.decode(data, string);
            (string path, DomainSetup setup, optional(TransferBackReason) error) = _buildRegisterParams(
                amount, sender, name, Gas.REGISTER_DOMAIN_VALUE
            );
            if (error.hasValue()) {
                _returnTokens(amount, sender, error.get());
                return;
            }
            _deployDomain(path, setup);
            sender.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false});
        } else if (kind == TransferKind.RENEW) {
            optional(string, address) params = _buildDomainCallParams(amount, sender, data, Gas.RENEW_DOMAIN_VALUE);
            if (!params.hasValue()) {
                return;
            }
            (string path, address domain) = params.get();
            emit Renewed(path);
            IDomain(domain).renew{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false  // todo if domain not exists
            }(amount, sender);
        } else if (kind == TransferKind.START_ZERO_AUCTION) {
            if (amount < _config.startZeroAuctionFee) {
                _returnTokens(amount, sender, TransferBackReason.LOW_TOKENS_AMOUNT);
                return;
            }
            optional(string, address) params = _buildDomainCallParams(amount, sender, data, Gas.START_ZERO_AUCTION_VALUE);
            if (!params.hasValue()) {
                return;
            }
            (string path, address domain) = params.get();
            emit ZeroAuctionStarted(path);
            IDomain(domain).startZeroAuction{
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED,
                bounce: false  // todo if domain not exists
            }(_auctionConfig, amount, sender);
        } else {
            _returnTokens(amount, sender, TransferBackReason.UNKNOWN_TRANSFER);
        }
    }

    function returnTokensFromDomain(
        string path, uint128 amount, address recipient, TransferBackReason reason
    ) public override onlyCertificate(path) {
        _reserve();
        _returnTokens(amount, recipient, reason);
    }


    function deploySubdomain(string path, string name, SubdomainSetup setup) public view override onlyCertificate(path) {
        path = name + "." + path;  // todo Constants.SEPARATOR
        optional(TransferBackReason) error;
        if (!_active) error.set(TransferBackReason.IS_NOT_ACTIVE);
        if (!_isCorrectName(name)) error.set(TransferBackReason.INVALID_NAME);
        if (!_isCorrectPathLength(path)) error.set(TransferBackReason.TOO_LONG_PATH);
        if (error.hasValue()) {
            IOwner(setup.creator).onCreateSubdomainError{
                value: 0,
                flag: MsgFlag.REMAINING_GAS,
                bounce: false
            }(path, error);
            return;
        }
        _deploySubdomain(path, setup);
    }

    function confiscate(string path, string reason, address owner) public view override onlyDao {
        _reserve();
        emit Confiscated(path, reason, owner);
        address certificate = _certificateAddress(path);
        NFTCertificate(certificate).confiscate{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(owner);
    }

    function reserve(string[] paths, string reason) public view override onlyDao cashBack {
        for (string path : paths) {
            emit Reserved(path, reason);
            DomainSetup setup = DomainSetup({
                owner: _dao,
                price: 0,
                reserved: true,
                needZeroAuction: false,
                expireTime: Constants.RESERVED_EXPIRE_TIME,
                amount: 0
            });
            _deployDomain(path, setup);
        }
    }

    function unreserve(
        string path, string reason, address owner, uint128 price, uint32 expireTime, bool needZeroAuction
    ) public view override onlyDao minValue(Gas.UNRESERVE_VALUE) {
        _reserve();
        emit Unreserved(path, reason, owner);
        address certificate = _certificateAddress(path);
        IDomain(certificate).unreserve{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED,
            bounce: false
        }(owner, price, expireTime, needZeroAuction);
    }


    function activate() public override onlyAdmin cashBack {
        _active = true;
    }

    function deactivate() public override onlyAdmin cashBack {
        _active = false;
    }

    function changePriceConfig(PriceConfig priceConfig) public override onlyDao cashBack {
        _priceConfig = priceConfig;
    }

    function changeConfigs(
        optional(RootConfig) config,
        optional(AuctionConfig) auctionConfig,
        optional(DurationConfig) durationConfig
    ) public override onlyDao cashBack {
        if (config.hasValue()) _config = config.get();
        if (auctionConfig.hasValue()) _auctionConfig = auctionConfig.get();
        if (durationConfig.hasValue()) _durationConfig = durationConfig.get();
    }

    function changeAdmin(address admin) public override onlyAdmin {
        _admin = admin;
    }

    function changeDao(address dao) public override onlyDao {
        _dao = dao;
    }


    function _buildTokensTransferPayload(string name, TransferKind kind) private view inline returns (TvmCell) {
        require(_isCorrectName(name), ErrorCodes.INVALID_NAME);
        TvmCell data = abi.encode(name);
        return abi.encode(kind, data);
    }

    function _buildRegisterParams(
        uint128 amount, address sender, string name, uint128 minValue
    ) private view returns (string, DomainSetup, optional(TransferBackReason)) {
        DomainSetup empty;
        (string path, optional(TransferBackReason) error) = _buildPathParams(name, minValue);
        if (error.hasValue()) {
            return ("", empty, error.get());
        }
        (uint128 price, bool needZeroAuction) = _calcPrice(name);
        if (price == 0) {
            return ("", empty, TransferBackReason.NOT_FOR_SALE);
        }
        uint32 duration = Converter.toDuration(amount, price);
        if (duration < _config.minDuration || duration > _config.maxDuration) {
            return ("", empty, TransferBackReason.INVALID_DURATION);
        }
        DomainSetup setup = DomainSetup({
            owner: sender,
            price: price,
            reserved: false,
            needZeroAuction: needZeroAuction,
            expireTime: now + duration,
            amount: amount
        });
        return (path, setup, null);
    }

    function _buildDomainCallParams(
        uint128 amount, address sender, TvmCell data, uint128 minValue
    ) private returns (optional(string, address)) {
        string name = abi.decode(data, string);
        (string path, optional(TransferBackReason) error) = _buildPathParams(name, minValue);
        if (error.hasValue()) {
            _returnTokens(amount, sender, error.get());
            return null;
        }
        address domain = _certificateAddress(path);
        _upgradeToLatest(Constants.DOMAIN_SID, domain, _wallet, Gas.UPGRADE_SLAVE_VALUE, 0);
        return optional(string, address)((path, domain));
    }

    function _buildPathParams(string name, uint128 minValue) private view returns (string, optional(TransferBackReason)) {
        if (msg.value < minValue) {
            return ("", TransferBackReason.LOW_MSG_VALUE);
        }
        if (!_isCorrectName(name)) {
            return ("", TransferBackReason.INVALID_NAME);
        }
        string path = _createPath(name);
        if (!_isCorrectPathLength(path)) {
            return ("", TransferBackReason.TOO_LONG_PATH);
        }
        return (path, null);
    }

    function _isCorrectName(string name) private view inline returns (bool) {
        return NameChecker.isCorrectName(name, _config.maxNameLength);
    }

    function _createPath(string name) internal view inline returns (string) {
        return name + "." + _tld;  // todo Constants.SEPARATOR
    }

    function _isCorrectPathLength(string path) private view inline returns (bool) {
        return path.byteLength() <= _config.maxPathLength;
    }

    function _calcPrice(string name) private view returns (uint128 price, bool needZeroAuction) {
        uint32 length = name.byteLength();
        if (length < _priceConfig.shortPrices.length) {
            price = _priceConfig.shortPrices[length];
        } else {
            price = _priceConfig.longPrice;
        }
        if (NameChecker.isOnlyLetters(name)) {
            price += math.muldiv(_priceConfig.onlyLettersFeePercent, price, Constants.PERCENT_DENOMINATOR);
        }
        needZeroAuction = length >= _priceConfig.noZeroAuctionLength;
        return (price, needZeroAuction);
    }

    function _deployDomain(string path, DomainSetup setup) private view {
        TvmCell code = _getLatestCode(Constants.DOMAIN_SID);
        DomainConfig domainConfig = DomainConfig(_config.maxDuration, _config.graceFinePercent);
        TvmCell params = abi.encode(path, _durationConfig, domainConfig, setup, _indexCode);
        _deployCertificate(path, Gas.DEPLOY_DOMAIN_VALUE, MsgFlag.SENDER_PAYS_FEES, code, params);
    }

    function _deploySubdomain(string path, SubdomainSetup setup) private view {
        TvmCell code = _getLatestCode(Constants.SUBDOMAIN_SID);
        TvmCell params = abi.encode(path, _durationConfig, setup, _indexCode);
        _deployCertificate(path, Gas.DEPLOY_DOMAIN_VALUE, MsgFlag.SENDER_PAYS_FEES, code, params);
    }

    function _deployCertificate(string path, uint128 value, uint8 flag, TvmCell code, TvmCell params) private view {
        uint256 id = tvm.hash(path);
        TvmCell stateInit = _buildCertificateStateInit(id);
        new Platform{
            stateInit: stateInit,
            value: value,
            flag: flag,
            bounce: false
        }(code, params);
    }

    function _returnTokens(uint128 amount, address recipient, TransferBackReason reason) private {
        TvmCell payload = abi.encode(reason);
        _transferTokens(amount, recipient, payload);
    }

    function _targetBalance() internal view inline override returns (uint128) {
        return Gas.ROOT_TARGET_BALANCE;
    }


    function upgradeToLatest(
        uint16 sid, address destination, address remainingGasTo
    ) public view override minValue(Gas.UPGRADE_SLAVE_VALUE) {
        _upgradeToLatest(sid, destination, remainingGasTo, 0, MsgFlag.REMAINING_GAS);
    }

    function upgradeToSpecific(
        uint16 sid, address destination, Version version, TvmCell code, TvmCell params, address remainingGasTo
    ) public view override minValue(Gas.UPGRADE_SLAVE_VALUE) {
        _upgradeToSpecific(sid, destination, version, code, params, remainingGasTo, 0, MsgFlag.REMAINING_GAS);
    }

    function setVersionActivation(uint16 sid, Version version, bool active) public override onlyAdmin {
        _setVersionActivation(sid, version, active);
    }

    function createNewDomainVersion(bool minor, TvmCell code, TvmCell params) public override onlyAdmin {
        _createNewVersion(Constants.DOMAIN_SID, minor, code, params);
    }

    function createNewSubdomainVersion(bool minor, TvmCell code, TvmCell params) public override onlyAdmin {
        _createNewVersion(Constants.SUBDOMAIN_SID, minor, code, params);
    }

    function upgrade(TvmCell code) public internalMsg override onlyAdmin {
        emit CodeUpgraded();
        TvmCell data = abi.encode(
            _totalSupply, _nftCode, _indexBasisCode, _indexCode,  // CollectionBase4_1 + CollectionBase4_3
            _platformCode,  // Collection
            _token, _wallet, _balance,  // Vault
            _slaves,  // BaseMaster
            _randomNonce,  // RandomNonce
            _tld, _dao, _admin, _active, _config, _priceConfig, _auctionConfig, _durationConfig  // Root
        );
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell input) private {
        tvm.resetStorage();
        (
            _totalSupply, _nftCode, _indexBasisCode, _indexCode,  // CollectionBase4_1 + CollectionBase4_3
            _platformCode,  // Collection
            _token, _wallet, _balance,  // Vault
            _slaves,  // BaseMaster
            _randomNonce,  // RandomNonce
            _tld, _dao, _admin, _active, _config, _priceConfig, _auctionConfig, _durationConfig  // Root
        ) = abi.decode(input, (
            uint128, TvmCell, TvmCell, TvmCell,  // CollectionBase4_1 + CollectionBase4_3
            TvmCell,  // Collection
            address, address, uint128,  // Vault
            mapping(uint16 => SlaveData),  // BaseMaster
            uint,  // RandomNonce
            string, address, address, bool, RootConfig, PriceConfig, AuctionConfig, DurationConfig  // Root
        ));
    }

}
