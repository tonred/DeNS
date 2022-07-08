pragma ton-solidity >= 0.61.2;


library Constants {

    // Domain price duration unit
    // For example, 1 year means that all prices are for 1 year
    uint128 constant DURATION_UNIT = 60 * 60 * 24 * 365;  // 1 year

    // Denominator of all percents (see Configs.sol)
    uint128 constant PERCENT_DENOMINATOR = 100_000;

    // Separator between parts of domain like "sub.domain.tld"
    string constant SEPARATOR = ".";

}
