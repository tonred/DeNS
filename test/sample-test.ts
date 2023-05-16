import { expect } from "chai";
import { Address, Contract, Signer } from "locklift";
import { factorySource, FactorySource } from "../build/factorySource";
import { deployRoot, deployRootDeployer, deployTestToken, deployWallet } from "../scripts/deploy";
import { logContract } from "../scripts/utils";
import BigNumber from "bignumber.js";
import { Account } from "locklift/internal/factory";

enum CertificateStatus {
  RESERVED,
  NEW,
  IN_ZERO_AUCTION,
  COMMON,
  EXPIRING,
  GRACE,
  EXPIRED
}

const MAX_NAME_LENGTH = 63;
const MAX_PATH_LENGTH = 253;
const MIN_DURATION = 60 * 60 * 24 * 365; // 1 year
const MAX_DURATION = MIN_DURATION * 10;  // 10 years
const GRACE_FINE_PERCENT = 0;
const AUCTION_DURATION = 3600 * 24;
const START_ZERO_AUCTION_FEE = Number(new BigNumber(10).shiftedBy(9).toFixed());
const LONG_PRICE = Number(new BigNumber(50).shiftedBy(9).toFixed());
const NEED_ZERO_AUC_LEN = 11;

let balance = 0;

let account: Account<FactorySource["Wallet"]>;
let account2: Account<FactorySource["Wallet"]>;
let fakeAuction: Account<FactorySource["Wallet"]>;
let token: Contract<FactorySource["TokenRoot"]>;
let tokenWallet: Contract<FactorySource["TokenWallet"]>;
let vaultTokenWallet: Contract<FactorySource["TokenWallet"]>;
let root: Contract<FactorySource["Root"]>;
let signer: Signer;
let domainStore: Record<string, Contract<FactorySource["Domain"]>> = {};
let subdomainStore: Record<string, Contract<FactorySource["Subdomain"]>> = {};
describe("Test DeNS contract", async function() {
  before(async () => {
    signer = (await locklift.keystore.getSigner("0"))!;
    account = await deployWallet(signer, locklift.utils.toNano(100));
    fakeAuction = await deployWallet(signer, locklift.utils.toNano(20));
    account2 = await deployWallet(signer, locklift.utils.toNano(10));
    token = await deployTestToken(signer, account.address);
    tokenWallet = locklift.factory.getDeployedContract(
      "TokenWallet",
      (await token.methods.walletOf({ answerId: 0, walletOwner: account.address }).call()).value0,
    );
    locklift.tracing.setAllowedCodesForAddress(account.address, { compute: [60] });

  });
  describe("Artifacts", async function() {
    it("Load Root contract factory", async function() {
      for (let contract of ["Domain", "Index", "IndexBasis", "Platform", "Root", "RootDeployer", "Subdomain"]) {
        const contractData = locklift.factory.getAllArtifacts().filter(c => c.contractName == contract)[0].artifacts;

        expect(contractData).not.to.equal(undefined, `${contract} Code should be available`);
        expect(contractData.code).not.to.equal(undefined, `${contract} Code should be available`);
        expect(contractData.abi).not.to.equal(undefined, `${contract} ABI should be available`);
        expect(contractData.tvc).not.to.equal(undefined, `${contract} tvc should be available`);
      }

    });
  });
  describe("Initialization", async function() {
    it("Deploy Root contract", async function() {
      const deployer = await deployRootDeployer(signer, locklift.utils.toNano(10));
      const _root = await deployRoot(
        signer,
        deployer,
        "test",
        JSON.stringify({
          "type": "Everscale Domain",
          "name": ".ever domains",
          "description": "Everscale domains .ever",
          "preview": {
            "source": "https://ipfs.grandbazar.io/ipfs/QmYxBG98XDvJ5Q87JWa1CQY2qwWrqFETchR1rKUT7b56e8",
            "mimetype": "image/png",
            "width": 320,
            "height": 320,
            "size": 30074,
            "format": "png",
          },
          "files": [],
          "external_url": "https://grandbazar.io/collection/ambient",
        }),
        account.address, // dao
        account.address, // admin
        {
          maxNameLength: MAX_NAME_LENGTH,
          maxPathLength: MAX_PATH_LENGTH,
          minDuration: MIN_DURATION,
          maxDuration: MAX_DURATION,
          graceFinePercent: GRACE_FINE_PERCENT,
          startZeroAuctionFee: START_ZERO_AUCTION_FEE,
        },
        {
          longPrice: LONG_PRICE,
          shortPrices: [
            Number(new BigNumber(99999999).shiftedBy(9).toFixed()),
            Number(new BigNumber(100).shiftedBy(9).toFixed()),
            Number(new BigNumber(90).shiftedBy(9).toFixed()),
            Number(new BigNumber(80).shiftedBy(9).toFixed()),
            Number(new BigNumber(70).shiftedBy(9).toFixed()),
            Number(new BigNumber(60).shiftedBy(9).toFixed()),
          ],
          onlyLettersFeePercent: 100_000,
          needZeroAuctionLength: NEED_ZERO_AUC_LEN,
        },
        {
          auctionRoot: account.address,
          tokenRoot: token.address,
          duration: AUCTION_DURATION,
        },
        {
          startZeroAuction: 60 * 60 * 24,
          expiring: 0,
          grace: 0,
        },
      );
      if (_root) root = _root;
      expect((await root.methods._tld().call())._tld).to.be.equal("test", "Root TLD does not match");
      expect((await root.methods._dao().call())._dao.equals(account.address))
        .to.be.equal(true, "Root dao does not match");
      expect((await root.methods._admin().call())._admin.equals(account.address))
        .to.be.equal(true, "Root admin does not match");

      vaultTokenWallet = locklift.factory.getDeployedContract(
        "TokenWallet",
        (await token.methods.walletOf({ answerId: 0, walletOwner: root.address }).call()).value0,
      );
    });
    it("Activate Root contract", async function() {
      expect((await root.methods._active().call())._active)
        .to.be.equal(false, "Root after deploy need to be deactivated");
      await locklift.tracing.trace(account.runTarget(
        { contract: root, value: locklift.utils.toNano(2) },
        root =>
          root.methods.activate({}),
      ));
      expect((await root.methods._active().call())._active)
        .to.be.equal(true, "Root is not active after activation");
    });
  });
  describe("Domains", async function() {
    describe("Names", async function() {
    });
    describe("Reserved", async function() {
      describe("Domain", async function() {
        it("Reserve domain", async function() {
          const domainName = "domain.test";
          const { certificate: expectedDomainAddress } = await root.methods.resolve({
            answerId: 0,
            path: domainName,
          }).call();
          expect(await locklift.provider.getBalance(expectedDomainAddress))
            .to.be.equal("0", "Domain balance before deploy is not zero");
          await locklift.tracing.trace(account.runTarget(
            { contract: root, value: locklift.utils.toNano(5) },
            root =>
              root.methods.reserve({ paths: [domainName], reason: "Some reason", owner: null }),
          ));
          const domain = locklift.factory.getDeployedContract("Domain", expectedDomainAddress);
          domainStore[domainName] = domain;
          await logContract(`Domain(${domainName})`, domain);
          expect((await domain.methods.getStatus({ answerId: 0 }).call()).status)
            .to.be.equal(CertificateStatus.RESERVED.toString(), "Domain status after reservation is not RESERVED");
          expect((await domain.methods.getPath({ answerId: 0 }).call()).path)
            .to.be.equal(domainName, "Domain path does not match with domain");
          expect((await domain.methods._root({}).call())._root.equals(root.address))
            .to.be.equal(true, "Domain root does not match");
          expect((await domain.methods._owner({}).call())._owner.equals(account.address))
            .to.be.equal(true, "Domain owner does not match");
          expect((await domain.methods._needZeroAuction({}).call())._needZeroAuction)
            .to.be.equal(false, "Reserved domain does not need auction");
        });
        describe("Records", async function() {
          it("Target", async function() {
            const domain = domainStore["domain.test"];
            await locklift.tracing.trace(account.runTarget(
              { contract: domain, value: locklift.utils.toNano(2) },
              domain =>
                domain.methods.setTarget({ target: account.address }),
            ));
            expect((await domain.methods.resolve({ answerId: 0 }).call()).target.equals(account.address))
              .to.be.equal(true, "Domain target address does not match");
            await locklift.tracing.trace(account.runTarget(
              { contract: domain, value: locklift.utils.toNano(2) },
              domain =>
                domain.methods.deleteRecord({ key: 0 }),
            ));
            expect((await domain.methods.resolve({ answerId: 0 }).call()).target.toString())
              .to.be.equal("", "Domain target address does not match after delete");
          });
          it("Record(0)", async function() {
            const domain = domainStore["domain.test"];
            await locklift.tracing.trace(account.runTarget(
              { contract: domain, value: locklift.utils.toNano(2) },
              domain =>
                domain.methods.setRecord({
                  key: 0,
                  value: "te6ccgEBAQEAJAAAQ4ACRgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABA=",
                }),
            ));
            await account.runTarget(
              { contract: domain, value: locklift.utils.toNano(2) },
              domain =>
                domain.methods.setRecord({
                  key: 0,
                  value: "te6ccgEBAgEACgACAAEBAAh0ZXN0",
                }),
            );
            await account.runTarget(
              { contract: domain, value: locklift.utils.toNano(2) },
              domain =>
                domain.methods.setRecord({
                  key: 0,
                  value: "te6ccgEBAQEAIwAAQgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==",
                }),
            );
            expect((await domain.methods.resolve({ answerId: 0 }).call()).target.equals(new Address("0:1230000000000000000000000000000000000000000000000000000000000000")))
              .to.be.equal(true, "Domain target address does not match");
          });
          it("Record(N)", async function() {
            const domain = domainStore["domain.test"];
            await account.runTarget(
              { contract: domain, value: locklift.utils.toNano(2) },
              domain =>
                domain.methods.setRecord({
                  key: 1,
                  value: "te6ccgECCwEABJgAAQABAf5Mb3JlbSBpcHN1bSBkb2xvciBzaXQgYW1ldCwgY29uc2VjdGV0dXIgYWRpcGlzY2luZyBlbGl0LiBGdXNjZSBsdWN0dXMgZXggcXVpcyBzY2VsZXJpc3F1ZSBhbGlxdWV0LiBDcmFzIG5vbiBlbmltIGluIGxlbyBhdWN0b3IgAgH+c2NlbGVyaXNxdWUuIEV0aWFtIHRlbGx1cyBsaWd1bGEsIHRpbmNpZHVudCBpZCBkaWFtIHZlaGljdWxhLCBpYWN1bGlzIHVsbGFtY29ycGVyIHNhcGllbi4gSW4gZGlhbSBtZXR1cywgYmxhbmRpdCBhdCBtaSB1dCwgY29udgMB/mFsbGlzIGltcGVyZGlldCBkaWFtLiBEdWlzIGNvbnNlcXVhdCBlZ2VzdGFzIGNvbW1vZG8uIE5hbSB2aXRhZSBjdXJzdXMgbGliZXJvLCBuZWMgYXVjdG9yIHNlbS4gQ3JhcyB2YXJpdXMgYXVndWUgdml0YWUgZWdlc3RhcyAEAf5mYXVjaWJ1cy4gQ3VyYWJpdHVyIGludGVyZHVtIG1vbGVzdGllIGFsaXF1ZXQuIE9yY2kgdmFyaXVzIG5hdG9xdWUgcGVuYXRpYnVzIGV0IG1hZ25pcyBkaXMgcGFydHVyaWVudCBtb250ZXMsIG5hc2NldHVyIHJpZGljdWx1BQH+cyBtdXMuIE51bmMgYSBsaWJlcm8gb3JjaS4gUHJvaW4gZWdldCBvcm5hcmUgb3JjaS4gTnVsbGEgbGFjdXMgZW5pbSwgYWxpcXVldCBmZXJtZW50dW0gZWxlaWZlbmQgZWdldCwgY29uc2VjdGV0dXIgdXQgdHVycGlzLgoKTQYB/mF1cmlzIGhlbmRyZXJpdCBwdXJ1cyB1dCBwb3J0YSBtYXhpbXVzLiBNb3JiaSBzdXNjaXBpdCwgbGliZXJvIHF1aXMgY29uc2VjdGV0dXIgdmVuZW5hdGlzLCBqdXN0byBsb3JlbSBtb2xsaXMgbGVjdHVzLCBhYyBwaGFyZXQHAf5yYSBsaWd1bGEgb3JjaSBhYyBsaWJlcm8uIEN1cmFiaXR1ciBwaGFyZXRyYSB1cm5hIHV0IHRlbXB1cyBtb2xsaXMuIER1aXMgZWxlaWZlbmQsIGxlY3R1cyB1dCBzb2xsaWNpdHVkaW4gbHVjdHVzLCBudWxsYSBuZXF1ZSBzCAH+dXNjaXBpdCBtZXR1cywgZXQgcG9ydGEgZmVsaXMgYXVndWUgdXQgbGlndWxhLiBQcmFlc2VudCBzZW1wZXIgc2FnaXR0aXMgZXJhdCwgbm9uIG1vbGxpcyBlcmF0IGFsaXF1ZXQgbmVjLiBBZW5lYW4gZXQgcmhvbmN1cyBleAkB/i4gTWFlY2VuYXMgbG9yZW0gbG9yZW0sIGFsaXF1YW0gaW4gdHVycGlzIHBlbGxlbnRlc3F1ZSwgZmVybWVudHVtIGNvbnNlY3RldHVyIGFyY3UuIFF1aXNxdWUgdGluY2lkdW50IGFsaXF1YW0gdHVycGlzIGFjIHBvc3VlcmUKAAIu",
                }),
            );
            expect((await domain.methods.query({ answerId: 0, key: 1 }).call()).value)
              .to.be.equal(null, "Record value is not null");
            await locklift.tracing.trace(account.runTarget(
              { contract: domain, value: locklift.utils.toNano(2) },
              domain =>
                domain.methods.setRecord({
                  key: 1,
                  value: "te6ccgEBAQEAIgAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATS",
                }),
            ));
            expect((await domain.methods.query({ answerId: 0, key: 1 }).call()).value)
              .to.be.equal("te6ccgEBAQEAIgAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATS", "Record does not match");
          });
        });

      });
      describe("Subdomain", async function() {
        it("Registration", async function() {
          const subdomainName = "subdomain.domain.test";
          const domain = domainStore["domain.test"];

          const { certificate: expectedSubdomainAddress } = await root.methods.resolve({
            answerId: 0,
            path: subdomainName,
          }).call();
          expect(await locklift.provider.getBalance(expectedSubdomainAddress))
            .to.be.equal("0", "Subdomain balance before deploy is not zero");
          await locklift.tracing.trace(account.runTarget(
            { contract: domain, value: locklift.utils.toNano(10) },
            domain =>
              domain.methods.createSubdomain({
                name: "subdomain",
                owner: account.address,
                renewable: true,
              }),
          ));
          const subdomain = locklift.factory.getDeployedContract("Subdomain", expectedSubdomainAddress);
          subdomainStore["subdomain.domain.test"] = subdomain;
          await logContract(`Subdomain(${subdomainName})`, subdomain);
          expect((await subdomain.methods.getStatus({ answerId: 0 }).call()).status)
            .to.be.equal(CertificateStatus.COMMON.toString(), "Subdomain status after reservation is not COMMON");
          expect((await subdomain.methods.getPath({ answerId: 0 }).call()).path)
            .to.be.equal(subdomainName, "Subdomain path does not match with domain");
          expect((await subdomain.methods._root({}).call())._root.equals(root.address))
            .to.be.equal(true, "Subdomain root does not match");
          expect((await subdomain.methods._parent({}).call())._parent.equals(domain.address))
            .to.be.equal(true, "Subdomain parent does not match");
          expect((await subdomain.methods._owner({}).call())._owner.equals(account.address))
            .to.be.equal(true, "Subdomain owner does not match");
          expect((await subdomain.methods._renewable({}).call())._renewable)
            .to.be.equal(true, "Subdomain is not renewable");
          expect((await subdomain.methods._expireTime({}).call())._expireTime)
            .to.be.equal((await domain.methods._expireTime({}).call())._expireTime, "Subdomain expireTime does not match with domain expireTime");
        });
        describe("Records", async function() {
          it("Target", async function() {
            const subdomain = subdomainStore["subdomain.domain.test"];
            await locklift.tracing.trace(account.runTarget(
              { contract: subdomain, value: locklift.utils.toNano(2) },
              subdomain =>
                subdomain.methods.setTarget({ target: account.address }),
            ));
            expect((await subdomain.methods.resolve({ answerId: 0 }).call()).target.equals(account.address))
              .to.be.equal(true, "Subdomain target address does not match");
          });
          it("Record(0)", async function() {
            const subdomain = subdomainStore["subdomain.domain.test"];
            await locklift.tracing.trace(account.runTarget(
              { contract: subdomain, value: locklift.utils.toNano(2) },
              subdomain =>
                subdomain.methods.setRecord({
                  key: 0,
                  value: "te6ccgEBAQEAJAAAQ4ACRgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABA=",
                }),
            ));
            await account.runTarget(
              { contract: subdomain, value: locklift.utils.toNano(2) },
              subdomain =>
                subdomain.methods.setRecord({
                  key: 0,
                  value: "te6ccgEBAgEACgACAAEBAAh0ZXN0",
                }),
            );
            await account.runTarget(
              { contract: subdomain, value: locklift.utils.toNano(2) },
              subdomain =>
                subdomain.methods.setRecord({
                  key: 0,
                  value: "te6ccgEBAQEAIwAAQgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==",
                }),
            );
            expect((await subdomain.methods.resolve({ answerId: 0 }).call()).target.equals(new Address("0:1230000000000000000000000000000000000000000000000000000000000000")))
              .to.be.equal(true, "Subdomain target address does not match");
          });
          it("Record(N)", async function() {
            const subdomain = subdomainStore["subdomain.domain.test"];
            await account.runTarget(
              { contract: subdomain, value: locklift.utils.toNano(2) },
              subdomain =>
                subdomain.methods.setRecord({
                  key: 1,
                  value: "te6ccgECCwEABJgAAQABAf5Mb3JlbSBpcHN1bSBkb2xvciBzaXQgYW1ldCwgY29uc2VjdGV0dXIgYWRpcGlzY2luZyBlbGl0LiBGdXNjZSBsdWN0dXMgZXggcXVpcyBzY2VsZXJpc3F1ZSBhbGlxdWV0LiBDcmFzIG5vbiBlbmltIGluIGxlbyBhdWN0b3IgAgH+c2NlbGVyaXNxdWUuIEV0aWFtIHRlbGx1cyBsaWd1bGEsIHRpbmNpZHVudCBpZCBkaWFtIHZlaGljdWxhLCBpYWN1bGlzIHVsbGFtY29ycGVyIHNhcGllbi4gSW4gZGlhbSBtZXR1cywgYmxhbmRpdCBhdCBtaSB1dCwgY29udgMB/mFsbGlzIGltcGVyZGlldCBkaWFtLiBEdWlzIGNvbnNlcXVhdCBlZ2VzdGFzIGNvbW1vZG8uIE5hbSB2aXRhZSBjdXJzdXMgbGliZXJvLCBuZWMgYXVjdG9yIHNlbS4gQ3JhcyB2YXJpdXMgYXVndWUgdml0YWUgZWdlc3RhcyAEAf5mYXVjaWJ1cy4gQ3VyYWJpdHVyIGludGVyZHVtIG1vbGVzdGllIGFsaXF1ZXQuIE9yY2kgdmFyaXVzIG5hdG9xdWUgcGVuYXRpYnVzIGV0IG1hZ25pcyBkaXMgcGFydHVyaWVudCBtb250ZXMsIG5hc2NldHVyIHJpZGljdWx1BQH+cyBtdXMuIE51bmMgYSBsaWJlcm8gb3JjaS4gUHJvaW4gZWdldCBvcm5hcmUgb3JjaS4gTnVsbGEgbGFjdXMgZW5pbSwgYWxpcXVldCBmZXJtZW50dW0gZWxlaWZlbmQgZWdldCwgY29uc2VjdGV0dXIgdXQgdHVycGlzLgoKTQYB/mF1cmlzIGhlbmRyZXJpdCBwdXJ1cyB1dCBwb3J0YSBtYXhpbXVzLiBNb3JiaSBzdXNjaXBpdCwgbGliZXJvIHF1aXMgY29uc2VjdGV0dXIgdmVuZW5hdGlzLCBqdXN0byBsb3JlbSBtb2xsaXMgbGVjdHVzLCBhYyBwaGFyZXQHAf5yYSBsaWd1bGEgb3JjaSBhYyBsaWJlcm8uIEN1cmFiaXR1ciBwaGFyZXRyYSB1cm5hIHV0IHRlbXB1cyBtb2xsaXMuIER1aXMgZWxlaWZlbmQsIGxlY3R1cyB1dCBzb2xsaWNpdHVkaW4gbHVjdHVzLCBudWxsYSBuZXF1ZSBzCAH+dXNjaXBpdCBtZXR1cywgZXQgcG9ydGEgZmVsaXMgYXVndWUgdXQgbGlndWxhLiBQcmFlc2VudCBzZW1wZXIgc2FnaXR0aXMgZXJhdCwgbm9uIG1vbGxpcyBlcmF0IGFsaXF1ZXQgbmVjLiBBZW5lYW4gZXQgcmhvbmN1cyBleAkB/i4gTWFlY2VuYXMgbG9yZW0gbG9yZW0sIGFsaXF1YW0gaW4gdHVycGlzIHBlbGxlbnRlc3F1ZSwgZmVybWVudHVtIGNvbnNlY3RldHVyIGFyY3UuIFF1aXNxdWUgdGluY2lkdW50IGFsaXF1YW0gdHVycGlzIGFjIHBvc3VlcmUKAAIu",
                }),
            );
            expect((await subdomain.methods.query({ answerId: 0, key: 1 }).call()).value)
              .to.be.equal(null, "Record value is not null");
            await locklift.tracing.trace(account.runTarget(
              { contract: subdomain, value: locklift.utils.toNano(2) },
              subdomain =>
                subdomain.methods.setRecord({
                  key: 1,
                  value: "te6ccgEBAQEAIgAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATS",
                }),
            ));
            expect((await subdomain.methods.query({ answerId: 0, key: 1 }).call()).value)
              .to.be.equal("te6ccgEBAQEAIgAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATS", "Record does not match");
          });
        });
        describe("Ownership", async function() {
          it("Transfer", async function() {
            const domain = domainStore["domain.test"];
            const subdomain = subdomainStore["subdomain.domain.test"];

            await locklift.tracing.trace(account.runTarget(
              { contract: subdomain, value: locklift.utils.toNano(2) },
              subdomain =>
                subdomain.methods.transfer({ to: domain.address, sendGasTo: account.address, callbacks: [] }),
            ));
            expect((await subdomain.methods._owner({}).call())._owner.equals(domain.address))
              .to.be.equal(true, "Subdomain owner after transfer does not match");
          });
        });
      });
    });
    describe("Registration", async function() {
      it("Long with no zero auction", async function() {
        const name = "long-no-zero-auction";
        const domainName = "long-no-zero-auction.test";
        const { certificate: expectedDomainAddress } = await root.methods.resolve({
          answerId: 0,
          path: domainName,
        }).call();
        const { price: price, needZeroAuction } = await root.methods.expectedPrice({ answerId: 0, name: name }).call();
        expect(needZeroAuction).to.be.equal(false, "Domain needZeroAuction does not match");
        expect(price).to.be.equal(LONG_PRICE.toString(), "Domain price does not match");
        const registrationPayload = (await root.methods.buildRegisterPayload({
          answerId: 0,
          name: name,
        }).call()).payload;
        await locklift.tracing.trace(account.runTarget(
          { contract: tokenWallet, value: locklift.utils.toNano(5) },
          wallet =>
            wallet.methods.transfer({
              recipient: root.address,
              remainingGasTo: account.address,
              deployWalletValue: 0,
              payload: registrationPayload,
              amount: LONG_PRICE,
              notify: true,
            }),
        ));
        balance += LONG_PRICE;
        expect(Number((await root.methods._balance().call())._balance))
          .to.be.equal(balance, "Root balance does not match after register domain");

        const noZeroAuctionDomain = locklift.factory.getDeployedContract("Domain", expectedDomainAddress);
        domainStore[domainName] = noZeroAuctionDomain;
        await logContract(`Domain(${domainName})`, noZeroAuctionDomain);
        expect((await noZeroAuctionDomain.methods.getStatus({ answerId: 0 }).call()).status)
          .to.be.equal(CertificateStatus.COMMON.toString(), "Domain status after reservation is not COMMON");
        expect((await noZeroAuctionDomain.methods.getPath({ answerId: 0 }).call()).path)
          .to.be.equal(domainName, "Domain path does not match with domain");
        expect((await noZeroAuctionDomain.methods._root({}).call())._root.equals(root.address))
          .to.be.equal(true, "Domain root does not match");
        expect((await noZeroAuctionDomain.methods._owner({}).call())._owner.equals(account.address))
          .to.be.equal(true, "Domain owner does not match");
        expect((await noZeroAuctionDomain.methods._needZeroAuction({}).call())._needZeroAuction)
          .to.be.equal(false, "Long no zero auction domain does not need auction");
        const initTime = Number((await noZeroAuctionDomain.methods._initTime().call())._initTime);
        const expireTime = Number((await noZeroAuctionDomain.methods._expireTime().call())._expireTime);
        expect(expireTime - initTime)
          .to.be.equal(MIN_DURATION, "Domain expire time does not match");

      });
      // long name price
      // short prices
      // only letters percent
    });
    describe("Renew", async function() {
      it("Renew common domain", async function() {
        const name = "long-no-zero-auction";
        const domainName = "long-no-zero-auction.test";
        const domain = domainStore[domainName];

        const expireTime = Number((await domain.methods._expireTime().call())._expireTime);
        const nextExpireTime = expireTime + MIN_DURATION;
        const { amount } = await domain.methods.expectedRenewAmount({
          answerId: 0,
          newExpireTime: nextExpireTime,
        }).call();
        expect(Number(amount)).to.be.equal(LONG_PRICE, "Domain renew price does not match");

        const renewPayload = (await root.methods.buildRenewPayload({
          answerId: 0,
          name: name,
        }).call()).payload;

        await locklift.tracing.trace(account.runTarget(
          { contract: tokenWallet, value: locklift.utils.toNano(5) },
          wallet =>
            wallet.methods.transfer({
              recipient: root.address,
              remainingGasTo: account.address,
              deployWalletValue: 0,
              payload: renewPayload,
              amount: amount,
              notify: true,
            }),
        ));
        balance += Number(amount);

        const newExpireTime = Number((await domain.methods._expireTime().call())._expireTime);
        expect(newExpireTime).to.be.equal(nextExpireTime, "Domain new expire time after renew does not match");
        expect(Number((await root.methods._balance().call())._balance))
          .to.be.equal(balance, "Root balance does not match after renew");

      });
    });
    describe("Auction", async function() {
      it("Register short name", async function() {
        const name = "short";
        const domainName = "short.test";
        const price6 = Number(new BigNumber(60).shiftedBy(9).multipliedBy(2).toFixed());
        const { certificate: expectedDomainAddress } = await root.methods.resolve({
          answerId: 0,
          path: domainName,
        }).call();
        const { price: price, needZeroAuction } = await root.methods.expectedPrice({ answerId: 0, name: name }).call();
        expect(needZeroAuction).to.be.equal(true, "Domain needZeroAuction does not match");
        expect(price).to.be.equal(price6.toString(), "Domain price does not match");
        const registrationPayload = (await root.methods.buildRegisterPayload({
          answerId: 0,
          name: name,
        }).call()).payload;
        await locklift.tracing.trace(account.runTarget(
          { contract: tokenWallet, value: locklift.utils.toNano(5) },
          wallet =>
            wallet.methods.transfer({
              recipient: root.address,
              remainingGasTo: account.address,
              deployWalletValue: 0,
              payload: registrationPayload,
              amount: price6,
              notify: true,
            }),
        ));
        balance += price6;
        expect(Number((await root.methods._balance().call())._balance))
          .to.be.equal(balance, "Root balance does not match after register domain");

        const zeroAuctionDomain = locklift.factory.getDeployedContract("Domain", expectedDomainAddress);
        domainStore[domainName] = zeroAuctionDomain;
        await logContract(`Domain(${domainName})`, zeroAuctionDomain);
        expect((await zeroAuctionDomain.methods.getStatus({ answerId: 0 }).call()).status)
          .to.be.equal(CertificateStatus.NEW.toString(), "Domain status after reservation is not NEW");
        expect((await zeroAuctionDomain.methods.getPath({ answerId: 0 }).call()).path)
          .to.be.equal(domainName, "Domain path does not match with domain");
        expect((await zeroAuctionDomain.methods._needZeroAuction({}).call())._needZeroAuction)
          .to.be.equal(true, "Short domain need auction");
        expect((await zeroAuctionDomain.methods._inZeroAuction({}).call())._inZeroAuction)
          .to.be.equal(false, "Domain after registration cannot be in zero auction");
        const initTime = Number((await zeroAuctionDomain.methods._initTime().call())._initTime);
        const expireTime = Number((await zeroAuctionDomain.methods._expireTime().call())._expireTime);
        expect(expireTime - initTime)
          .to.be.equal(MIN_DURATION, "Domain expire time does not match");
      });
      it("Success auction", async function() {
        const name = "short";
        const domainName = "short.test";
        const domain = domainStore[domainName];
        const startZeroAuctionPayload = (await root.methods.buildStartZeroAuctionPayload({
          answerId: 0,
          name: name,
        }).call()).payload;
        await locklift.tracing.trace(account.runTarget(
          { contract: tokenWallet, value: locklift.utils.toNano(5) },
          wallet =>
            wallet.methods.transfer({
              recipient: root.address,
              remainingGasTo: account.address,
              deployWalletValue: 0,
              payload: startZeroAuctionPayload,
              amount: START_ZERO_AUCTION_FEE,
              notify: true,
            }),
        ));
        await locklift.tracing.trace(account.runTarget(
          { contract: tokenWallet, value: locklift.utils.toNano(5) },
          wallet =>
            wallet.methods.transfer({
              recipient: root.address,
              remainingGasTo: account.address,
              deployWalletValue: 0,
              payload: startZeroAuctionPayload,
              amount: START_ZERO_AUCTION_FEE,
              notify: true,
            }),
        ));
        balance += START_ZERO_AUCTION_FEE;
        expect(Number((await root.methods._balance().call())._balance))
          .to.be.equal(balance, "Root balance does not match after start auction + wrong start");
        expect((await domain.methods.getStatus({ answerId: 0 }).call()).status)
          .to.be.equal(CertificateStatus.IN_ZERO_AUCTION.toString(), "Domain status after start auction is not IN_ZERO_AUCTION");
        expect((await domain.methods._inZeroAuction({}).call())._inZeroAuction)
          .to.be.equal(true, "Domain auction needs to be started");
        expect((await domain.methods._auctionRoot({}).call())._auctionRoot.equals(account.address))
          .to.be.equal(true, "Domain _auctionRoot does not match");
        expect((await domain.methods._manager({}).call())._manager.equals(account.address))
          .to.be.equal(true, "Domain manager is not auction");

        // start auction
        await locklift.tracing.trace(account.runTarget(
          { contract: domain, value: locklift.utils.toNano(2) },
          domain =>
            domain.methods.changeManager({
              newManager: fakeAuction.address,
              sendGasTo: account.address,
              callbacks: [],
            }),
        ));
        expect((await domain.methods._manager({}).call())._manager.equals(fakeAuction.address))
          .to.be.equal(true, "Domain manager is not zeroAuction");
        expect((await domain.methods._zeroAuction({}).call())._zeroAuction.equals(fakeAuction.address))
          .to.be.equal(true, "Domain zero auction address does not match");
        expect((await domain.methods._owner({}).call())._owner.equals(account.address))
          .to.be.equal(true, "Domain owner does not match");

        // finish auction
        await locklift.tracing.trace(fakeAuction.runTarget(
          { contract: domain, value: locklift.utils.toNano(2) },
          domain =>
            domain.methods.transfer({
              to: account2.address,
              sendGasTo: account.address,
              callbacks: [],
            }),
        ));
        expect((await domain.methods._manager({}).call())._manager.equals(account2.address))
          .to.be.equal(true, "Domain manager is not new owner");
        expect((await domain.methods._inZeroAuction({}).call())._inZeroAuction)
          .to.be.equal(false, "Domain zero auction is finished");
        expect((await domain.methods._owner({}).call())._owner.equals(account2.address))
          .to.be.equal(true, "Domain owner does not match");
        expect((await domain.methods.getStatus({ answerId: 0 }).call()).status)
          .to.be.equal(CertificateStatus.COMMON.toString(), "Domain status after auctions is not COMMON");
      });
      it("Cancel auction", async function() {
        const name = "shor4";
        const domainName = "shor4.test";
        const price6 = Number(new BigNumber(60).shiftedBy(9).toFixed());
        const { certificate: expectedDomainAddress } = await root.methods.resolve({
          answerId: 0,
          path: domainName,
        }).call();
        const { price: price, needZeroAuction } = await root.methods.expectedPrice({ answerId: 0, name: name }).call();
        expect(needZeroAuction).to.be.equal(true, "Domain needZeroAuction does not match");
        expect(price).to.be.equal(price6.toString(), "Domain price does not match");
        const registrationPayload = (await root.methods.buildRegisterPayload({
          answerId: 0,
          name: name,
        }).call()).payload;
        await locklift.tracing.trace(account.runTarget(
          { contract: tokenWallet, value: locklift.utils.toNano(5) },
          wallet =>
            wallet.methods.transfer({
              recipient: root.address,
              remainingGasTo: account.address,
              deployWalletValue: 0,
              payload: registrationPayload,
              amount: price6,
              notify: true,
            }),
        ));
        balance += price6;

        const domain = locklift.factory.getDeployedContract("Domain", expectedDomainAddress);
        await logContract(`Domain(${domainName})`, domain);
        const startZeroAuctionPayload = (await root.methods.buildStartZeroAuctionPayload({
          answerId: 0,
          name: name,
        }).call()).payload;
        await locklift.tracing.trace(account.runTarget(
          { contract: tokenWallet, value: locklift.utils.toNano(5) },
          wallet =>
            wallet.methods.transfer({
              recipient: root.address,
              remainingGasTo: account.address,
              deployWalletValue: 0,
              payload: startZeroAuctionPayload,
              amount: START_ZERO_AUCTION_FEE,
              notify: true,
            }),
        ));

        balance += START_ZERO_AUCTION_FEE;

        // start auction
        await locklift.tracing.trace(account.runTarget(
          { contract: domain, value: locklift.utils.toNano(2) },
          domain =>
            domain.methods.changeManager({
              newManager: fakeAuction.address,
              sendGasTo: account.address,
              callbacks: [],
            }),
        ));
        expect((await domain.methods._manager({}).call())._manager.equals(fakeAuction.address))
          .to.be.equal(true, "Domain manager is not zeroAuction");
        expect((await domain.methods._zeroAuction({}).call())._zeroAuction.equals(fakeAuction.address))
          .to.be.equal(true, "Domain zero auction address does not match");
        expect((await domain.methods._owner({}).call())._owner.equals(account.address))
          .to.be.equal(true, "Domain owner does not match");

        // cancel auction
        await locklift.tracing.trace(fakeAuction.runTarget(
          { contract: domain, value: locklift.utils.toNano(2) },
          domain =>
            domain.methods.changeManager({
              newManager: account.address,
              sendGasTo: account.address,
              callbacks: [],
            }),
        ));
        expect((await domain.methods._manager({}).call())._manager.equals(account.address))
          .to.be.equal(true, "Domain manager is not old owner");
        expect((await domain.methods._needZeroAuction({}).call())._needZeroAuction)
          .to.be.equal(false, "Short domain does not need auction");
        expect((await domain.methods._inZeroAuction({}).call())._inZeroAuction)
          .to.be.equal(false, "Domain after cancel cannot be in zero auction");
        expect((await domain.methods.getStatus({ answerId: 0 }).call()).status)
          .to.be.equal(CertificateStatus.COMMON.toString(), "Domain status after auctions is not COMMON");
      });
    });
  });
});
