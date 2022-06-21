pragma ton-solidity >= 0.61.2;

import "../structures/Action.sol";


interface IRoot {

    function onWalletDeployed(address wallet) external;

    function checkName(string name) external responsible returns (bool correct);
    function expectedPrice(string name) external responsible returns (uint128 price);

    function onDomainDeployRetry(string name, uint128 amount, address sender) external;
    function onProlongReturn(string name, uint128 returnAmount, address sender) external;

    function resolve(string name) external responsible returns (address domain);
    function confiscate(string name, address owner, string reason) external;
    function reserve(string[] names, bool ignoreNameCheck, string reason) external;
    function execute(Action[] actions) external;
    function activate() external;
    function deactivate() external;

    function setDomainCode(TvmCell code) external;
    function requestDomainUpgrade(string name, uint16 version) external;

}
