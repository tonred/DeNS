pragma ton-solidity >= 0.61.2;

import "../structures/SubdomainSetup.sol";


interface IRoot {
    function onDomainDeployRetry(string path, uint128 amount, address sender) external;
    function onRenewReturn(string path, uint128 returnAmount, address sender) external;
    function deploySubdomain(string path, string name, SubdomainSetup setup) external view;
    function upgradeDomain(address domain) external view;
    function upgradeSubdomain(address subdomain) external view;
}
