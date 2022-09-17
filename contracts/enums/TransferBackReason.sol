pragma ever-solidity ^0.63.0;


enum TransferBackReason {

    // General
    IS_NOT_ACTIVE,      // 0
    LOW_MSG_VALUE,      // 1
    INVALID_NAME,       // 2
    TOO_LONG_PATH,      // 3
    INVALID_STATUS,     // 4

    // Register
    NOT_FOR_SALE,       // 5
    INVALID_DURATION,   // 6
    ALREADY_EXIST,      // 7

    // Renew
    INVALID_SENDER,     // 8
    ALREADY_RENEWED,    // 9
    DURATION_OVERFLOW,  // 10

    // Start Zero Auction
    LOW_TOKENS_AMOUNT,  // 11
    AUCTION_BUYOUT,     // 12

    // Other
    UNKNOWN_TRANSFER    // 13

}
