import { Signer } from "ethers";

import { ERC20 } from "../../typechain/ERC20";
import { ERC20__factory } from "../../typechain/factories/ERC20__factory";

import { Address } from "hardhat-deploy/dist/types";

export default class DeploMockContracts {
  private _deployerSigner: Signer;

  constructor(deployerSigner: Signer) {
    this._deployerSigner = deployerSigner;
  }

  public async deployMockERC20(): Promise<ERC20> {
    return await new ERC20__factory(this._deployerSigner).deploy();
  }

  public async getMockERC20(tokenAddress: Address): Promise<ERC20> {
    return await new ERC20__factory(this._deployerSigner).attach(tokenAddress);
  }
}
