pragma ever-solidity ^0.63.0;


library Constants {

    // Domain price duration unit
    // For example, 1 year means that all prices are for 1 year
    uint128 constant DURATION_UNIT = 60 * 60 * 24 * 365;  // 1 year

    // Denominator of all percents (see Configs.sol)
    uint128 constant PERCENT_DENOMINATOR = 100_000;

    // Expire time for reserved certificates (max uint32 value)
    uint32 constant RESERVED_EXPIRE_TIME = 2 ** 32 - 1;

    // CERTIFICATE (see Certificate.sol)
    // Max record cell size
    uint16 constant MAX_CELLS = 8;
    // Exact size of address var
    uint16 constant ADDRESS_SIZE = 267;
    // Record id of "target" record
    uint32 constant TARGET_RECORD_ID = 0;

    // VERSIONABLE
    uint16 constant DOMAIN_SID = 1;
    uint16 constant DOMAIN_VERSION_MAJOR = 1;
    uint16 constant DOMAIN_VERSION_MINOR = 5;
    uint16 constant SUBDOMAIN_SID = 2;
    uint16 constant SUBDOMAIN_VERSION_MAJOR = 1;
    uint16 constant SUBDOMAIN_VERSION_MINOR = 3;

    // Vault
    uint256 constant WEVER_ROOT_VALUE = 0x557957cba74ab1dc544b4081be81f1208ad73997d74ab3b72d95864a41b779a4;
    uint256 constant BLACK_HOLE_VALUE = 0xefd5a14409a8a129686114fc092525fddd508f1ea56d1b649a3a695d3a5b188c;

}
