pragma ton-solidity >= 0.61.2;


interface IRoot {
    function onDomainDeployRetry(string path, uint128 amount, address sender) external;
    function onProlongReturn(string path, uint128 returnAmount, address sender) external;
    function deploySubdomain(string path, string name, address owner, uint32 expireTime) external;
    function requestDomainUpgrade(string path, uint16 version) external;
    function requestSubdomainUpgrade(string path, uint16 version) external;
}
