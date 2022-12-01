pragma ever-solidity ^0.63.0;

import "../enums/CertificateStatus.sol";


interface ICertificate {

    function afterCodeUpgrade() external view;
    function getPath() external view responsible returns (string path);
    function getDetails() external view responsible returns (address owner, uint32 initTime, uint32 expireTime);
    function getStatus() external view responsible returns (CertificateStatus status);

    function resolve() external view responsible returns (address target);
    function query(uint32 key) external view responsible returns (optional(TvmCell) value);
    function getRecords() external view responsible returns (mapping(uint32 => TvmCell) records);

    function setTarget(address target) external;
    function setRecords(mapping(uint32 => TvmCell) records) external;
    function setRecord(uint32 key, TvmCell value) external;
    function deleteRecords(uint32[] keys) external;
    function deleteRecord(uint32 keys) external;

    function createSubdomain(string name, address owner, bool renewable) external view;
    function renewSubdomain(address subdomain) external view;

    function confiscate(address newOwner) external;
    function expire() external;

    function requestUpgrade() external view;

}
