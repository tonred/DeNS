pragma ton-solidity >= 0.61.2;


interface INFT {

    struct CallbackParams {
        uint128 value;      // ever value will be sent to address
        TvmCell payload;    // custom payload will be proxied to address
    }

    function getInfo() external view responsible returns (uint256 id, address owner, address manager, address collection);
    function changeOwner(address newOwner, address sendGasTo, mapping(address => CallbackParams) callbacks) external;
    function changeManager(address newManager, address sendGasTo, mapping(address => CallbackParams) callbacks) external;
    function transfer(address to, address sendGasTo, mapping(address => CallbackParams) callbacks) external;

    function prolong(uint32 expireTime) external;
    function unreserve(address owner, uint32 expireTime) external;
    function burn() external;
}
