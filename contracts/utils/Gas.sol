pragma ton-solidity >= 0.61.2;


library Gas {  // todo set values + remove unused

    // Root
    uint128 constant DEPLOY_WALLET_VALUE            = 1 ton;
    uint128 constant REGISTER_VALUE                 = 1 ton;
    uint128 constant PROLONG_VALUE                  = 1 ton;
    uint128 constant UPGRADE_DOMAIN_VALUE           = 1 ton;
    uint128 constant MINT_VALUE                     = 1 ton;
    uint128 constant DEPLOY_DOMAIN_VALUE            = 1 ton;

    // Certificate
    uint128 constant PROLONG_SUBDOMAIN_VALUE = 1 ton;


    // Domain
    uint128 constant START_ZERO_AUCTION_VALUE       = 1 ton;
    uint128 constant PROLONG_NFT_VALUE              = 1 ton;
    uint128 constant REQUEST_UPGRADE_DOMAIN_VALUE   = 1 ton;

    // NFT
    uint128 constant ON_MINT_VALUE                  = 0.2 ton;

}
