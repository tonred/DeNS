pragma ton-solidity >= 0.61.2;


library Gas {

    // From TIP4.3
    // uint128 constant DEPLOY_INDEX_VALUE = 0.2 ton;
    // uint128 constant DESTROY_INDEX_VALUE = 0.1 ton;

    // Vault
    uint128 constant DEPLOY_WALLET_VALUE        = 0.1 ton;

    // Root
    uint128 constant ROOT_TARGET_BALANCE        = 1 ton;
    uint128 constant REGISTER_DOMAIN_VALUE      = 2.9 ton;  // more than DEPLOY_DOMAIN_VALUE
    uint128 constant RENEW_DOMAIN_VALUE         = 1.5 ton;  // more than UPGRADE_DOMAIN_VALUE
    uint128 constant DEPLOY_DOMAIN_VALUE        = 2.5 ton;  // more than DOMAIN_TARGET_BALANCE + 2 * DEPLOY_INDEX_VALUE (TIP4.3)
    uint128 constant UNRESERVE_VALUE            = 1 ton;
    uint128 constant UPGRADE_DOMAIN_VALUE       = 1 ton;
    uint128 constant UPGRADE_SUBDOMAIN_VALUE    = 1 ton;

    // Certificate
    uint128 constant DEPLOY_SUBDOMAIN_VALUE     = 2.5 ton;  // more than SUBDOMAIN_TARGET_BALANCE + CREATOR_NOTIFY_VALUE + 2 * DEPLOY_INDEX_VALUE (TIP4.3)
    uint128 constant RENEW_SUBDOMAIN_VALUE      = 0.5 ton;

    // NFT Certificate
    uint128 constant ON_BURN_VALUE              = 0.2 ton;

    // Domain
    uint128 constant DOMAIN_TARGET_BALANCE      = 1 ton;
    uint128 constant START_ZERO_AUCTION_VALUE   = 10 ton;  // todo START_ZERO_AUCTION_VALUE

    // Subdomain
    uint128 constant SUBDOMAIN_TARGET_BALANCE   = 1 ton;
    uint128 constant CREATOR_NOTIFY_VALUE       = 0.3 ton;

}
