pragma ton-solidity >= 0.61.2;


enum TransferCanselReason {

    // Register
    LOW_MSG_VALUE,      // 0
    INVALID_NAME,       // 1
    NOT_FOR_SALE,       // 2
    LOW_TOKENS_AMOUNT,  // 3
    INVALID_DURATION,   // 4
    ALREADY_EXIST,      // 5

    // Prolong
    DURATION_OVERFLOW,  // 6

    // Other
    IS_NOT_ACTIVE,      // 7
    UNKNOWN_TYPE        // 8

}
