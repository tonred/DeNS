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
    function resolve(string path) external view responsible returns (address certificate);

    function onDomainDeployRetry(string path, uint128 amount, address sender) external;
    function onDomainRenewReturn(string path, uint128 returnAmount, address sender) external;

    function deploySubdomain(string path, string name, SubdomainSetup setup) external view;
    function confiscate(string path, address owner, string reason) external view;
    function reserve(string[] paths, string reason) external view;
    function execute(Action[] actions) external view;
    function activate() external;
    function deactivate() external;

    function upgradeDomain(address domain) external view;
    function upgradeSubdomain(address subdomain) external view;

}
