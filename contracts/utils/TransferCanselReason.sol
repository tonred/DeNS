pragma ton-solidity >= 0.61.2;


enum TransferCanselReason {

    // Register
    INVALID_NAME,       // 0
    NOT_FOR_SALE,       // 1
    LOW_TOKENS_AMOUNT,  // 2
    INVALID_DURATION,   // 3
    ALREADY_EXIST,      // 4

    // Prolong
    DURATION_OVERFLOW,  // 5

    // Other
    LOW_MSG_VALUE,      // 6
    IS_NOT_ACTIVE,      // 7
    UNKNOWN_TYPE        // 8

}
