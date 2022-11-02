# DeNS

## Deployed domains

| tld  | Address                                                             |
|------|---------------------------------------------------------------------|
| ever | 0:a7d0694c025b61e1a4a846f1cf88980a5df8adf737d17ac58e35bf172c9fca29  |

## Resolve
### To get a dns record for a specific domain:

On root contract for specific TLD call:

`resolve(string path) public view responsible returns (address certificate)`.

This method will return the address of the domain certificate. Check if such account exists and then call methods for obtaining DNS records from it:

`query(uint32 key) public view responsible returns (optional(TvmCell))`

| ID | description                                | ABI     |
|----|--------------------------------------------|---------|
| 0  | Everscale account address (target address) | address |
| 1  | ADNL address                               | uint256 |
|    |                                            |         |
|    | TBD                                        |         |
|    |                                            |         |
|    |                                            |         |

### Example
```solidity
// fake code
mapping(string => address) tld;
tld["ever"] = address(0:abc..);
string toResolve = "somedomain.ever";

Root root = Root(tld.find(toResolve));
address certificateAddr = root.resolve(toResolve);
if (!isAccountActive(certificateAddr)) return;
// Certificate can be domain or subdomain or just use Certificate interface
Domain domain = Domain(certificateAddr);
// id=0 to get Everscale account address record; 
optional(TvmCell) targetRecord = domain.query(0);
if(!targetRecord.hasValue()) return;
address target = targetRecord.get();
return target
```

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

1) Get price via `expectedRegisterAmount` in root
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
2) `owner` received:
    * `onMinted` callback if success
    * `onCreateSubdomainError` with `TransferBackReason.*` reason callback in case of error


## Architecture

todo image
