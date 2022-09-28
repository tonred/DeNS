import { Contract } from "locklift";
import { logger } from "locklift/build/logger";

export async function logContract(name: string, contract: Contract<any>): Promise<void> {
  const balance = await locklift.provider.getBalance(contract.address);
  logger.printInfo(`${name}: ${contract.address} - ${locklift.utils.fromNano(balance)} EVER`);
}