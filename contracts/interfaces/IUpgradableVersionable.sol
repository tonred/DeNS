pragma ton-solidity >= 0.61.2;


interface IUpgradableVersionable {
    event CodeUpgraded(uint16 oldVersion, uint16 newVersion);
    function requestUpgrade() external internalMsg;
    function upgrade(TvmCell code, uint16 version) external internalMsg;
}
