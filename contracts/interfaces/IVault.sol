pragma ton-solidity >= 0.61.2;


interface IVault {
    function onWalletDeployed(address wallet) external;
    function getToken() external view responsible returns (address token) ;
    function getWallet() external view responsible returns (address wallet);
    function getBalance() external view responsible returns (uint128 balance);
}
