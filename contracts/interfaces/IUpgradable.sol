pragma ton-solidity >= 0.57.3;


interface IUpgradable {
    event CodeUpgraded();
    function upgrade(TvmCell code) external internalMsg;
}
