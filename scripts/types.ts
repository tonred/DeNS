import { Address } from "locklift";

export type Config = {
  maxNameLength: number,
  maxPathLength: number,
  minDuration: number,
  maxDuration: number,
  graceFinePercent: number,
  startZeroAuctionFee: number,
}

export type AuctionConfig = {
  auctionRoot: Address,
  tokenRoot: Address,
  duration: number,
}

export type DurationConfig = {
  startZeroAuction: number,
  expiring: number,
  grace: number,
}
export type PriceConfig = {
  longPrice: number,
  shortPrices: number[],
  onlyLettersFeePercent: number,
  needZeroAuctionLength: number,
}