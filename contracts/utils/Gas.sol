pragma ever-solidity ^0.63.0;


library Gas {

    // From TIP4.3
    // uint128 constant DEPLOY_INDEX_VALUE = 0.2 ever;
    // uint128 constant DESTROY_INDEX_VALUE = 0.1 ever;

    // From Auction
    // uint128 constant DEPLOY_AUCTION_VALUE = 3 ever;
    // uint128 constant TRANSFER_OWNERSHIP_VALUE = 1.1 ever;
    // uint128 constant TOKENS_RECEIVED_CALLBACK_VALUE = 1 ever;

    // Vault
    uint128 constant DEPLOY_WALLET_VALUE        = 0.1 ever;

    // Root
    uint128 constant ROOT_TARGET_BALANCE        = 1 ever;
    uint128 constant REGISTER_DOMAIN_VALUE      = 2.5 ever;  // more than DEPLOY_DOMAIN_VALUE
    uint128 constant RENEW_DOMAIN_VALUE         = 2 ever;  // more than UPGRADE_SLAVE_VALUE + RETURN_TOKENS_VALUE
    uint128 constant START_ZERO_AUCTION_VALUE   = 5.5 ever;  // more than CREATE_ZERO_AUCTION_VALUE + ZERO_AUCTION_BID_VALUE
    uint128 constant DEPLOY_DOMAIN_VALUE        = 2 ever;  // more than DOMAIN_TARGET_BALANCE + 2 * DEPLOY_INDEX_VALUE[TIP4.3]
    uint128 constant CONFISCATE_VALUE           = 1 ever;
    uint128 constant UNRESERVE_VALUE            = 1 ever;
    uint128 constant UPGRADE_SLAVE_VALUE        = 1 ever;

    // Certificate
    uint128 constant AFTER_CODE_UPGRADE_VALUE   = 0.2 ever;
    uint128 constant DEPLOY_SUBDOMAIN_VALUE     = 2.5 ever;  // more than SUBDOMAIN_TARGET_BALANCE + CREATOR_NOTIFY_VALUE + 2 * DEPLOY_INDEX_VALUE[TIP4.3]
    uint128 constant RENEW_SUBDOMAIN_VALUE      = 0.5 ever;

    // NFT Certificate
    uint128 constant ON_BURN_VALUE              = 0.2 ever;

    // Domain
    uint128 constant DOMAIN_TARGET_BALANCE      = 1 ever;
    uint128 constant CREATE_ZERO_AUCTION_VALUE  = 5 ever;  // more than DEPLOY_AUCTION_VALUE[Auction]
    uint128 constant ZERO_AUCTION_BID_VALUE     = 1.5 ever;  // more than TOKENS_RECEIVED_CALLBACK_VALUE[Auction]
    uint128 constant RETURN_TOKENS_VALUE        = 0.2 ever;  // must be less than TRANSFER_OWNERSHIP_VALUE[Auction] - 2 * DEPLOY_INDEX_VALUE[TIP4.3]
    // Subdomain
    uint128 constant SUBDOMAIN_TARGET_BALANCE   = 1 ever;
    uint128 constant CREATOR_NOTIFY_VALUE       = 0.3 ever;

}
