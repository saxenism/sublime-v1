import { Signer } from "ethers";

import DeployCoreContracts from "./deployCoreContracts";

export default class DeployHelper {
  public core: DeployCoreContracts;

  constructor(deployerSigner: Signer) {
    this.core = new DeployCoreContracts(deployerSigner);
  }
}
