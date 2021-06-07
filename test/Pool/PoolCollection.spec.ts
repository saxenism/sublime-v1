import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { expect } from "chai";

import {
    aaveYieldParams,
    depositValueToTest,
    zeroAddress,
    Binance7 as binance7,
    WhaleAccount as whaleAccount,
    DAI_Yearn_Protocol_Address,
    testPoolFactoryParams,
    createPoolParams,
    ChainLinkAggregators,
  } from "../../utils/constants";
  import DeployHelper from "../../utils/deploys";
  
  import { SavingsAccount } from "../../typechain/SavingsAccount";
  import { StrategyRegistry } from "../../typechain/StrategyRegistry";
  import {
    getPoolAddress,
    getRandomFromArray,
    incrementChain,
  } from "../../utils/helpers";
  import { Address } from "hardhat-deploy/dist/types";
  import { AaveYield } from "../../typechain/AaveYield";
  import { YearnYield } from "../../typechain/YearnYield";
  import { CompoundYield } from "../../typechain/CompoundYield";
  import { Pool } from "../../typechain/Pool";
  import { Verification } from "../../typechain/Verification";
  import { PoolFactory } from "../../typechain/PoolFactory";
  import { ERC20 } from "../../typechain/ERC20";
  import { PriceOracle } from "../../typechain/PriceOracle";
  import { Extension } from "../../typechain/Extension";
  
  import { Contracts } from "../../existingContracts/compound.json";
  import { sha256 } from "@ethersproject/sha2";
  import { PoolToken } from "../../typechain/PoolToken";
  import { Repayments } from "../../typechain/Repayments";
  import { ContractTransaction } from "@ethersproject/contracts";
  import { getContractAddress } from "@ethersproject/address";  

describe('Pool collection stage', async () => {
    let savingsAccount: SavingsAccount;
    let strategyRegistry: StrategyRegistry;
    let extenstion: Extension;
    let poolImpl: Pool;
    let poolTokenImpl: PoolToken;
    let poolFactory: PoolFactory;
    let repaymentImpl: Repayments;

    let mockCreditLines: SignerWithAddress;
    let proxyAdmin: SignerWithAddress;
    let admin: SignerWithAddress;
    let borrower: SignerWithAddress;
    let lender: SignerWithAddress;

    let aaveYield: AaveYield;
    let yearnYield: YearnYield;
    let compoundYield: CompoundYield;

    let BatTokenContract: ERC20;
    let LinkTokenContract: ERC20;
    let DaiTokenContract: ERC20;

    let verification: Verification;
    let priceOracle: PriceOracle;

    let Binance7: any;
    let WhaleAccount: any;
    before(async () => {
        [proxyAdmin, admin, mockCreditLines, borrower, lender] = await ethers.getSigners();
        const deployHelper: DeployHelper = new DeployHelper(proxyAdmin);
        savingsAccount = await deployHelper.core.deploySavingsAccount();
        strategyRegistry = await deployHelper.core.deployStrategyRegistry();
        poolFactory = await deployHelper.pool.deployPoolFactory();
        extenstion = await deployHelper.pool.deployExtenstion();
        poolImpl = await deployHelper.pool.deployPool();

        //initialize
        savingsAccount.initialize(
            admin.address,
            strategyRegistry.address,
            mockCreditLines.address
        );
        strategyRegistry.initialize(admin.address, 10);

        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [binance7],
        });

        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [whaleAccount],
        });

        await admin.sendTransaction({
            to: whaleAccount,
            value: ethers.utils.parseEther("100"),
        });

        Binance7 = await ethers.provider.getSigner(binance7);
        WhaleAccount = await ethers.provider.getSigner(whaleAccount);

        BatTokenContract = await deployHelper.mock.getMockERC20(Contracts.BAT);
        await BatTokenContract.connect(Binance7).transfer(
            admin.address,
            BigNumber.from("10").pow(23)
        ); // 10,000 BAT tokens

        LinkTokenContract = await deployHelper.mock.getMockERC20(Contracts.LINK);
        await LinkTokenContract.connect(Binance7).transfer(
            admin.address,
            BigNumber.from("10").pow(23)
        ); // 10,000 LINK tokens

        DaiTokenContract = await deployHelper.mock.getMockERC20(Contracts.DAI);
        await DaiTokenContract.connect(WhaleAccount).transfer(
            admin.address,
            BigNumber.from("10").pow(23)
        ); // 10,000 DAI

        aaveYield = await deployHelper.core.deployAaveYield();
        await aaveYield
            .connect(admin)
            .initialize(
                admin.address,
                savingsAccount.address,
                aaveYieldParams._wethGateway,
                aaveYieldParams._protocolDataProvider,
                aaveYieldParams._lendingPoolAddressesProvider
            );

        await strategyRegistry.connect(admin).addStrategy(aaveYield.address);

        yearnYield = await deployHelper.core.deployYearnYield();
        await yearnYield.initialize(admin.address, savingsAccount.address);
        await strategyRegistry.connect(admin).addStrategy(yearnYield.address);
        await yearnYield
            .connect(admin)
            .updateProtocolAddresses(
                DaiTokenContract.address,
                DAI_Yearn_Protocol_Address
            );

        compoundYield = await deployHelper.core.deployCompoundYield();
        await compoundYield.initialize(admin.address, savingsAccount.address);
        await strategyRegistry.connect(admin).addStrategy(compoundYield.address);
        await compoundYield
            .connect(admin)
            .updateProtocolAddresses(Contracts.DAI, Contracts.cDAI);

        verification = await deployHelper.helper.deployVerification();
        await verification.connect(admin).initialize(admin.address);
        await verification
            .connect(admin)
            .registerUser(borrower.address, sha256(Buffer.from("Borrower")));

        priceOracle = await deployHelper.helper.deployPriceOracle();
        await priceOracle.connect(admin).initialize(admin.address);
        await priceOracle
            .connect(admin)
            .setfeedAddress(
                Contracts.LINK,
                Contracts.DAI,
                ChainLinkAggregators["LINK/USD"],
                ChainLinkAggregators["DAI/USD"]
            );
        
        await extenstion.connect(admin).initialize(poolFactory.address);
        let {
            _collectionPeriod,
            _marginCallDuration,
            _collateralVolatilityThreshold,
            _gracePeriodPenaltyFraction,
            _liquidatorRewardFraction,
            _matchCollateralRatioInterval,
            _poolInitFuncSelector,
            _poolTokenInitFuncSelector,
        } = testPoolFactoryParams;
        await poolFactory
            .connect(admin)
            .initialize(
                verification.address,
                strategyRegistry.address,
                admin.address,
                _collectionPeriod,
                _matchCollateralRatioInterval,
                _marginCallDuration,
                _collateralVolatilityThreshold,
                _gracePeriodPenaltyFraction,
                _poolInitFuncSelector,
                _poolTokenInitFuncSelector,
                _liquidatorRewardFraction,
                priceOracle.address,
                savingsAccount.address,
                extenstion.address
            );
    })

    describe("ETH as collateral and ERC20 as lent token", async () => {
        beforeEach(async() => {
            let {
                _poolSize,
                _minborrowAmount,
                _collateralRatio,
                _borrowRate,
                _repaymentInterval,
                _noOfRepaymentIntervals,
                _collateralAmount,
            } = createPoolParams;

            const salt = sha256(Buffer.from("borrower"+Math.random()*10000000));

            // Approve collateral

            await poolFactory
                .connect(borrower)
                .createPool(
                    _poolSize,
                    _minborrowAmount,
                    Contracts.DAI,
                    zeroAddress,
                    _collateralRatio,
                    _borrowRate,
                    _repaymentInterval,
                    _noOfRepaymentIntervals,
                    aaveYield.address,
                    _collateralAmount,
                    false,
                    salt
                );
        })
    })
})