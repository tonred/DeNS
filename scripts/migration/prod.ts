import { Address } from "locklift";
import { deployRoot, deployRootDeployer } from "../deploy";
import BigNumber from "bignumber.js";
import { logContract } from "../utils";

async function main() {
  const signer = (await locklift.keystore.getSigner("0"))!;
  const deployer = await deployRootDeployer(signer, locklift.utils.toNano(7));
  const root = await deployRoot(
    signer,
    deployer,
    "ever",
    JSON.stringify({
      "type": "Everscale Domain",
      "name": ".ever domains",
      "description": "Everscale domains .ever",
      "preview": {
        "source": "https://img.evername.io/ever",
        "mimetype": "image/png",
      },
      "files": [],
      "external_url": "https://evername.io",
    }),
    new Address("0:e4d671473db5b45f903b27feaeaa3591ea9f6300d653e84604a579e427650196"), // dao
    new Address("0:e4d671473db5b45f903b27feaeaa3591ea9f6300d653e84604a579e427650196"), // admin
    {
      maxNameLength: 63,
      maxPathLength: 253,
      minDuration: 60 * 60 * 24 * 365,
      maxDuration: 60 * 60 * 24 * 365 * 10, // 3 years
      graceFinePercent: 100_000,
      startZeroAuctionFee: Number(new BigNumber(10).shiftedBy(9).toFixed()),
    },
    {
      longPrice: Number(new BigNumber(0).shiftedBy(9).toFixed()),
      shortPrices: [],
      onlyLettersFeePercent: 100_000,
      needZeroAuctionLength: 0,
    },
    {
      auctionRoot: new Address("0:0000000000000000000000000000000000000000000000000000000000000000"),
      tokenRoot: new Address("0:a49cd4e158a9a15555e624759e2e4e766d22600b7800d891e46f9291f044a93d"),
      duration: 60 * 60 * 24 * 3,
    },
    {
      startZeroAuction: 60 * 60 * 24 * 3,
      expiring: 60 * 60 * 24 * 7,
      grace: 60 * 60 * 24 * 7,
    },
  );
  await logContract('Root', root!)
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
