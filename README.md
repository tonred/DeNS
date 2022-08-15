# DeNS
tonred team


## TODO

* Unreserve domain
* Versionable


## Methods

### Root
1) Find certificate address by full path
2) Create new domain
3) Renew exist domains
4) Confiscate domain via DAO voting
5) Reserve and unreserve domain via DAO voting
6) Execute any action via DAO voting
7) Activate or deactivate root contracts (only admin)

&#43; All TIP4 (TIP4.1, TIP4.2, TIP4.3) methods

### Subdomain
1) Resolve domain
2) Query record(s)
3) Change target or record
4) Create subdomain

&#43; All TIP4 (TIP4.1, TIP4.2, TIP4.3) methods

### Domain
All domain methods

&#43; Start auction in from new domains

&#43; All TIP4 (TIP4.1, TIP4.2, TIP4.3) methods


## Workflow

### [Certificate statuses](contracts/enums/CertificateStatus.sol)

0) `RESERVED` - reserved by dao
1) `NEW` - first N days domain is new, anybody can start auction
2) `IN_ZERO_AUCTION` - new domain that in auction new
3) `COMMON` - common certificate, nothing special
4) `EXPIRING` - domain will be expired in N days, user cannot create auction for it
5) `GRACE` - N days after expiring, where user can renew it for additional fee
6) `EXPIRED` - domain is fully expired (after grace period), anybody can destroy it

### Register new domain

Anyone can call

1) Get price via `expectedPriceForDuration` in root
2) Build payload via `buildRegisterPayload` in root
3) Send tokens and payload to root's TIP3 wallet with notify
4) Sender will receive
    * `onMinted` callback if success
    * Get tokens back with `TransferBackReason.ALREADY_EXIST` reason if domain already exist
    * Get tokens back with `TransferBackReason.*` reason in case of another errors

### Renew exist domain

Only domain owner can call

1) Get `expectedRenewAmount` in domain
2) Build payload via `buildRenewPayload` in root
3) Send tokens and payload to root's TIP3 wallet with notify
4) Sender will receive
    * `onRenewed` callback if success
    * Get tokens back with `TransferBackReason.DURATION_OVERFLOW` reason if duration is too big
    * Get tokens back with `TransferBackReason.*` reason in case of another errors

### Renew subdomain

todo...

### Create subdomain

1) Call `createSubdomain` in domain/subdomain, where:
    * `name` - name of subdomain
    * `owner` - owner of new subdomain
    * `renewable` - a flag that marks if owner of subdomain can renew it in any time
2) `owner` received:  // todo
    * `onMinted` callback if success
    * `onCreateSubdomainError` with `TransferBackReason.*` reason callback in case of error


## Architecture

todo image
