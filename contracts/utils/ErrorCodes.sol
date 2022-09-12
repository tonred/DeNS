pragma ever-solidity ^0.63.0;


library ErrorCodes {

    // Common
    uint16 constant IS_NOT_ROOT             = 1001;
    uint16 constant IS_NOT_OWNER            = 1002;
    uint16 constant IS_NOT_ACTIVE           = 1003;
    uint16 constant IS_NOT_CERTIFICATE      = 1004;

    // Certificate
    uint16 constant WRONG_STATUS            = 2001;
    uint16 constant INVALID_ADDRESS_CELL    = 2002;
    uint16 constant INVALID_ADDRESS_TYPE    = 2003;
    uint16 constant TOO_BIG_CELL            = 2004;

    // NFT Certificate
    uint16 constant IS_NOT_MANAGER          = 3001;

    // Vault
    uint16 constant IS_NOT_TOKEN_ROOT       = 4001;
    uint16 constant IS_NOT_TOKEN_WALLET     = 4002;

    // Subdomain
    uint16 constant IS_NOT_PARENT           = 5001;
    uint16 constant IS_NOT_RENEWABLE        = 5002;

    // Root
    uint16 constant IS_NOT_DAO              = 6001;
    uint16 constant IS_NOT_ADMIN            = 6002;
    uint16 constant IS_NOT_AUCTION_ROOT     = 6003;
    uint16 constant INVALID_DURATION        = 6004;
    uint16 constant INVALID_NAME            = 6005;
    uint16 constant INVALID_SID             = 6006;  // Slave ID, see Versionable

}
