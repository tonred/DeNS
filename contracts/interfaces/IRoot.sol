pragma ton-solidity >= 0.61.2;

import "../structures/Action.sol";
import "../structures/Configs.sol";
import "../structures/DeployConfigs.sol";
import "../structures/SubdomainSetup.sol";


interface IRoot {

    function getDetails() external view responsible returns (string tld, address dao, bool active);
    function getConfigs() external view responsible returns (
        RootConfig config,
        DomainDeployConfig domainDeployConfig,
        SubdomainDeployConfig subdomainDeployConfig
    );
    function checkName(string name) external view responsible returns (bool correct);
    function expectedPrice(string name) external view responsible returns (uint128 price);
    function expectedRegisterAmount(string name, uint32 duration) external view responsible returns (uint128 amount);
    function resolve(string path) external view responsible returns (address certificate);

    function buildRegisterPayload(string name) external view responsible returns (TvmCell payload);
    function buildRenewPayload(string name) external view responsible returns (TvmCell payload);

    function onDomainDeployRetry(string path, uint128 amount, address sender) external;
    function onDomainRenewReturn(string path, uint128 returnAmount, address sender) external;

    function deploySubdomain(string path, string name, SubdomainSetup setup) external view;
    function confiscate(string path, string reason, address owner) external view;
    function reserve(string[] paths, string reason) external view;
    function unreserve(string path, string reason, address owner, uint128 price, uint32 expireTime, bool needZeroAuction) external view;
    function execute(Action[] actions) external view;
    function activate() external;
    function deactivate() external;

    function upgradeDomain(address domain) external view;
    function upgradeSubdomain(address subdomain) external view;

}
