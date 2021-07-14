import { Signer } from 'ethers';

import { Verification } from '../../typechain/Verification';
import { PriceOracle } from '../../typechain/PriceOracle';

import { Verification__factory } from '../../typechain/factories/Verification__factory';
import { PriceOracle__factory } from '../../typechain/factories/PriceOracle__factory';

import { Address } from 'hardhat-deploy/dist/types';

export default class DeployHelperContracts {
    private _deployerSigner: Signer;

    constructor(deployerSigner: Signer) {
        this._deployerSigner = deployerSigner;
    }

    public async deployVerification(): Promise<Verification> {
        return await new Verification__factory(this._deployerSigner).deploy();
    }

    public async getVerification(verificationAddress: Address): Promise<Verification> {
        return await new Verification__factory(this._deployerSigner).attach(verificationAddress);
    }

    public async deployPriceOracle(): Promise<PriceOracle> {
        return await new PriceOracle__factory(this._deployerSigner).deploy();
    }

    public async getPriceOracle(priceOracleAddress: Address): Promise<PriceOracle> {
        return await new PriceOracle__factory(this._deployerSigner).attach(priceOracleAddress);
    }
}
