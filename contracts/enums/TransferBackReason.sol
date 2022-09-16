pragma ever-solidity ^0.63.0;


enum TransferBackReason {

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
    AUCTION_BUYOUT,     // 8

    // Renew
    INVALID_SENDER,     // 9
    INVALID_STATUS,     // 10
    ALREADY_RENEWED,    // 11
    DURATION_OVERFLOW,  // 12

    // Other
    UNKNOWN_TRANSFER    // 13

}
