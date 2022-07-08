pragma ton-solidity >= 0.61.2;


library Gas {  // todo set values + remove unused

    // Vault
    uint128 constant DEPLOY_WALLET_VALUE        = 1 ton;

    // Root
    uint128 constant ROOT_TARGET_BALANCE      = 1 ton;
    uint128 constant REGISTER_VALUE             = 1 ton;
    uint128 constant RENEW_VALUE              = 1 ton;
    uint128 constant DEPLOY_DOMAIN_VALUE        = 1 ton;
    uint128 constant UPGRADE_DOMAIN_VALUE       = 1 ton;
    uint128 constant UPGRADE_SUBDOMAIN_VALUE    = 1 ton;

    // Certificate
    uint128 constant DEPLOY_SUBDOMAIN_VALUE     = 1 ton;
    uint128 constant RENEW_SUBDOMAIN_VALUE    = 1 ton;

    // NFT Certificate
    uint128 constant ON_MINT_VALUE              = 0.2 ton;
    uint128 constant ON_BURN_VALUE              = 0.2 ton;

    // Domain
    uint128 constant DOMAIN_TARGET_BALANCE   = 1 ton;
    uint128 constant START_ZERO_AUCTION_VALUE   = 1 ton;

    // Subdomain
    uint128 constant SUBDOMAIN_TARGET_BALANCE   = 1 ton;

}
