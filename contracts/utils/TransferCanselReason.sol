pragma ton-solidity >= 0.61.2;


enum TransferCanselReason {

    // General
    IS_NOT_ACTIVE,      // 0
    LOW_MSG_VALUE,      // 1
    INVALID_NAME,       // 2
    TOO_LONG_PATH,      // 3
    ALREADY_EXIST,      // 4

    // Register
    NOT_FOR_SALE,       // 5
    LOW_TOKENS_AMOUNT,  // 6
    INVALID_DURATION,   // 7

    // Renew
    DURATION_OVERFLOW,  // 8

    // Other
    UNKNOWN_TRANSFER    // 9

}
