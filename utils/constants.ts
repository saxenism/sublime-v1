import { BigNumber } from "@ethersproject/bignumber";
import { Address } from "hardhat-deploy/dist/types";

export const depositValueToTest: BigNumber = BigNumber.from(
  "1000000000000000000"
); // 1 ETH (or) 10^18 Tokens
export const zeroAddress: Address =
  "0x0000000000000000000000000000000000000000";

export const aaveYieldParams = {
  _wethGateway: "0xDcD33426BA191383f1c9B431A342498fdac73488",
  _protocolDataProvider: "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
  _lendingPoolAddressesProvider: "0xb53c1a33016b2dc2ff3653530bff1848a515c8c5",
};

export const ETH_Yearn_Protocol_Address =
  "0xe1237aa7f535b0cc33fd973d66cbf830354d16c7";

export const Binance7 = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";
export const WhaleAccount = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503";
export const DAI_Yearn_Protocol_Address =
  "0xacd43e627e64355f1861cec6d3a6688b31a6f952";

export const aLink = "0xa06bC25B5805d5F8d82847D191Cb4Af5A3e873E0";
