pragma ton-solidity >= 0.61.2;

import {Version} from "versionable/contracts/utils/Structs.sol";


library Constants {

    // Domain price duration unit
    // For example, 1 year means that all prices are for 1 year
    uint128 constant DURATION_UNIT = 60 * 60 * 24 * 365;  // 1 year

    // Denominator of all percents (see Configs.sol)
    uint128 constant PERCENT_DENOMINATOR = 100_000;

    // Separator between parts of domain like "sub.domain.tld"
    string constant SEPARATOR = ".";

    // Versionable
    uint16 constant DOMAIN_SID = 1;
    uint16 constant DOMAIN_VERSION_MAJOR = 1;
    uint16 constant DOMAIN_VERSION_MINOR = 1;
    uint16 constant SUBDOMAIN_SID = 2;
    uint16 constant SUBDOMAIN_VERSION_MAJOR = 1;
    uint16 constant SUBDOMAIN_VERSION_MINOR = 1;

}
