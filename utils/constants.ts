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
