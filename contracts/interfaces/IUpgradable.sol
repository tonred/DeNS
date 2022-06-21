pragma ton-solidity >= 0.61.2;


interface IUpgradable {
    event CodeUpgraded();
    function upgrade(TvmCell code) external internalMsg;
}
