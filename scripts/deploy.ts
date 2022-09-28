import { Address, Contract, Signer } from "locklift";
import { RootAbi, RootDeployerAbi, TokenRootAbi, WalletAbi } from "../build/factorySource";
import { AuctionConfig, Config, DurationConfig, PriceConfig } from "./types";
import { logContract } from "./utils";
import { Account } from "locklift/build/factory";
import { logger } from "locklift/build/logger";
import BigNumber from "bignumber.js";

export async function deployRootDeployer(signer: Signer, value: string): Promise<Contract<RootDeployerAbi>> {
  logger.printInfo(`Deploy RootDeployer...`);
  const { contract: rootDeployer, tx } = await locklift.factory.deployContract({
    contract: "RootDeployer",
    publicKey: signer.publicKey,
    initParams: {
      _randomNonce: locklift.utils.getRandomNonce(),
    },
    constructorParams: {
      platformCode: locklift.factory.getContractArtifacts("Platform").code,
    },
    value: value,
  });
  await logContract("RootDeployer", rootDeployer);
  await rootDeployer.methods.setRootCode({ rootCode: locklift.factory.getContractArtifacts("Root").code }).sendExternal({ publicKey: signer.publicKey });
  logger.printInfo(`Set RootCode`);
  await rootDeployer.methods.setDomainCode({ domainCode: locklift.factory.getContractArtifacts("Domain").code }).sendExternal({ publicKey: signer.publicKey });
  logger.printInfo(`Set DomainCode`);
  await rootDeployer.methods.setSubdomainCode({ subdomainCode: locklift.factory.getContractArtifacts("Subdomain").code }).sendExternal({ publicKey: signer.publicKey });
  logger.printInfo(`Set SubdomainCode`);
  await rootDeployer.methods.setIndexBasisCode({ indexBasisCode: locklift.factory.getContractArtifacts("IndexBasis").code }).sendExternal({ publicKey: signer.publicKey });
  logger.printInfo(`Set IndexBasisCode`);
  await rootDeployer.methods.setIndexCode({ indexCode: locklift.factory.getContractArtifacts("Index").code }).sendExternal({ publicKey: signer.publicKey });
  logger.printInfo(`Set IndexCode`);
  return rootDeployer;
}

export async function deployRoot(
  signer: Signer,
  rootDeployer: Contract<RootDeployerAbi>,
  tld: string,
  json: string,
  dao: Address,
  admin: Address,
  config: Config,
  priceConfig: PriceConfig,
  auctionConfig: AuctionConfig,
  durationConfig: DurationConfig,
): Promise<Contract<RootAbi> | undefined> {
  logger.printInfo(`Deploy Root(${tld})...`);

  const tx = await rootDeployer.methods.NewRoot({
    randomNonce: locklift.utils.getRandomNonce(),
    tld,
    json,
    dao,
    admin,
    config,
    priceConfig,
    auctionConfig,
    durationConfig,
  }).sendExternal({ publicKey: signer.publicKey });
  if (tx.output) {
    const root = locklift.factory.getDeployedContract("Root", tx.output?.value0);
    await logContract("Root", root);
    return root;
  } else {
    logger.printError(`Root not deployed tx = ${tx.transaction.id} 
    exit/result code = ${tx.transaction.exitCode}/${tx.transaction.resultCode}`);
  }
}

export async function deployTestToken(signer: Signer, owner: Address): Promise<Contract<TokenRootAbi>> {
  logger.printInfo(`Deploy TokenRoot...`);
  const { contract: token, tx } = await locklift.factory.deployContract({
    contract: "TokenRoot",
    publicKey: signer.publicKey,
    initParams: {
      deployer_: new Address("0:0000000000000000000000000000000000000000000000000000000000000000"),
      randomNonce_: locklift.utils.getRandomNonce(),
      rootOwner_: owner,
      name_: "Test",
      symbol_: "TST",
      decimals_: 9,
      walletCode_: locklift.factory.getContractArtifacts("TokenWallet").code,
    },
    constructorParams: {
      initialSupplyTo: owner,
      initialSupply: new BigNumber(100_000).shiftedBy(9).toFixed(),
      deployWalletValue: locklift.utils.toNano(0.1),
      mintDisabled: false,
      burnByRootDisabled: false,
      burnPaused: false,
      remainingGasTo: owner,
    },
    value: locklift.utils.toNano(1.5),
  });
  return token;
}

export async function deployWallet(signer: Signer, value: string): Promise<Account<WalletAbi>> {
  logger.printInfo(`Deploy Wallet...`);
  const Wallet = locklift.factory.getAccountsFactory("Wallet");
  const { account: wallet } = await Wallet.deployNewAccount({
    publicKey: signer.publicKey,
    initParams: {
      _randomNonce: locklift.utils.getRandomNonce(),
    },
    constructorParams: {},
    value: value,
  });
  await logContract("Wallet", wallet.accountContract);
  return wallet;
}