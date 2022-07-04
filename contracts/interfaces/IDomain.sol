pragma ton-solidity >= 0.61.2;

import "../structures/Config.sol";
import "../structures/InputRecord.sol";
import "../utils/DomainStatus.sol";


interface IDomain {

    function onDeployRetry(TvmCell /*code*/, TvmCell params, address /*remainingGasTo*/) external functionID(0x3F61459C);

    function getName() external responsible returns (string name);
    function getDetails() external responsible returns (
        address nft, address owner, uint128 defaultPrice, uint128 currentPrice, bool reserved, uint32 initTime, uint32 expireTime
    );
    function getConfigDetails() external responsible returns (uint16 version, Config config);
    function getAuctionDetails() external responsible returns (bool inZeroAuction, bool needZeroAuction);
    function getStatus() external responsible returns (DomainStatus status);

    function resolve() external responsible returns (address target);
    function resolveQuery(string group, string query) external responsible returns (optional(string[]) values);
    function getRecords() external responsible returns (mapping(uint256 => mapping(uint256 => string[])) records);
    function getRecordsCount(string group) external responsible returns (uint256 count);
    function checkRecords(string group, InputRecord[] records) external responsible returns (bool correct);
    function setTarget(address target) external;
    function setRecords(string group, InputRecord[] records) external;
    function setRecord(string group, InputRecord record) external;
    function deleteRecords(string group, string[] templates) external;

    function startZeroAuction() external;
    function zeroAuctionFinished() external;

    function expectedProlongAmount(uint32 duration) external responsible returns (uint128 amount);
    function prolong(uint128 amount, address sender) external;
    function nftOwnerChanged(address newOwner) external;

    function confiscate(address newOwner) external;
    function unreserve(address owner, uint128 price, uint32 expireTime, bool needZeroAuction) external;
    function expire() external;

    function requestUpgrade() external;
    function upgrade(uint16 version, TvmCell code, Config config) external;

}
