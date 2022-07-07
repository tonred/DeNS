pragma ton-solidity >= 0.61.2;


enum CertificateStatus {
    RESERVED,           // 0
    NEW,                // 1
    IN_ZERO_AUCTION,    // 2
    COMMON,             // 3
    EXPIRING,           // 4
    GRACE,              // 5
    EXPIRED             // 6
}
