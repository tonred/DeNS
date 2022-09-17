pragma ever-solidity ^0.63.0;

import "../enums/TransferBackReason.sol";
import "../structures/Configs.sol";
import "../structures/SubdomainSetup.sol";

import {Version} from "versionable/contracts/utils/Structs.sol";


interface IRoot {

    function getPath() external view responsible returns (string path);
    function getDetails() external view responsible returns (string tld, address dao, bool active);
    function getConfigs() external view responsible returns (
        RootConfig config, PriceConfig priceConfig, AuctionConfig auctionConfig, DurationConfig durationConfig
    );
    function checkName(string name) external view responsible returns (bool correct);
    function expectedPrice(string name) external view responsible returns (uint128 price, bool needZeroAuction);
    function expectedRegisterAmount(string name, uint32 duration) external view responsible returns (uint128 amount);
    function resolve(string path) external view responsible returns (address certificate);
    function expectedCertificateCodeHash(address target, uint16 sid) external view responsible returns (uint256 codeHash);

    function buildRegisterPayload(string name) external view responsible returns (TvmCell payload);
    function buildRenewPayload(string name) external view responsible returns (TvmCell payload);
    function buildStartZeroAuctionPayload(string name) external view responsible returns (TvmCell payload);
    function returnTokensFromDomain(string path, uint128 amount, address recipient, TransferBackReason reason) external;

    function deploySubdomain(string path, string name, SubdomainSetup setup) external view;
    function confiscate(string path, string reason, address owner) external view;
    function reserve(string[] paths, string reason) external view;
    function unreserve(string path, string reason, address owner, uint128 price, uint32 expireTime, bool needZeroAuction) external view;

    function activate() external;
    function deactivate() external;
    function changePriceConfig(PriceConfig priceConfig) external;
    function changeConfigs(
        optional(RootConfig) config,
        optional(AuctionConfig) auctionConfig,
        optional(DurationConfig) durationConfig
    ) external;
    function changeAdmin(address admin) external;
    function changeDao(address dao) external;

    function upgradeToLatest(uint16 sid, address destination, address remainingGasTo) external view;
    function upgradeToSpecific(
        uint16 sid, address destination, Version version, TvmCell code, TvmCell params, address remainingGasTo
    ) external view;
    function setVersionActivation(uint16 sid, Version version, bool active) external;
    function createNewDomainVersion(bool minor, TvmCell code, TvmCell params) external;
    function createNewSubdomainVersion(bool minor, TvmCell code, TvmCell params) external;

}
