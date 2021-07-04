import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { assert, expect } from "chai";

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
  repaymentParams
} from "../../utils/constants";
import DeployHelper from "../../utils/deploys";

import { SavingsAccount } from "../../typechain/SavingsAccount";
import { StrategyRegistry } from "../../typechain/StrategyRegistry";
import {
  getPoolAddress,
  getRandomFromArray
} from "../../utils/helpers";
import {
    incrementChain,
    timeTravel,
    blockTravel
} from "../../utils/time";
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
import { IYield } from "@typechain/IYield";

describe.only("Pool Borrow Active stage", async () => {
    let savingsAccount: SavingsAccount;
    let strategyRegistry: StrategyRegistry;

    let mockCreditLines: SignerWithAddress;
    let proxyAdmin: SignerWithAddress;
    let admin: SignerWithAddress;
    let borrower: SignerWithAddress;
    let lender: SignerWithAddress;
    let lender1: SignerWithAddress;
    let random: SignerWithAddress;

    let extenstion: Extension;
    let poolImpl: Pool;
    let poolTokenImpl: PoolToken;
    let poolFactory: PoolFactory;
    let repaymentImpl: Repayments;

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
        [proxyAdmin, admin, mockCreditLines, borrower, lender, lender1, random] = await ethers.getSigners();
        const deployHelper: DeployHelper = new DeployHelper(proxyAdmin);
        savingsAccount = await deployHelper.core.deploySavingsAccount();
        strategyRegistry = await deployHelper.core.deployStrategyRegistry();

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
                ChainLinkAggregators["LINK/USD"]
            );
        await priceOracle
            .connect(admin)
            .setfeedAddress(
                Contracts.DAI,
                ChainLinkAggregators["DAI/USD"]
            );

        poolFactory = await deployHelper.pool.deployPoolFactory();
        extenstion = await deployHelper.pool.deployExtenstion();
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
            _poolCancelPenalityFraction
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
                extenstion.address,
                _poolCancelPenalityFraction
            );
        await poolFactory
            .connect(admin)
            .updateSupportedBorrowTokens(Contracts.LINK, true);

        await poolFactory
            .connect(admin)
            .updateSupportedCollateralTokens(Contracts.DAI, true);

        poolImpl = await deployHelper.pool.deployPool();
        poolTokenImpl = await deployHelper.pool.deployPoolToken();
        repaymentImpl = await deployHelper.pool.deployRepayments();

        await repaymentImpl.connect(admin).initialize(
            admin.address, 
            poolFactory.address, 
            repaymentParams.votingPassRatio, 
            repaymentParams.gracePenalityRate, 
            repaymentParams.gracePeriodFraction, 
            savingsAccount.address
        );

        await poolFactory
            .connect(admin)
            .setImplementations(
                poolImpl.address,
                repaymentImpl.address,
                poolTokenImpl.address
            );
    });

    describe.only("Pool that borrows ERC20 with ERC20 as collateral", async () => {
        let pool: Pool;
        let poolToken: PoolToken;
        let collateralToken: ERC20;
        let borrowToken: ERC20;
        let amount: BigNumber;
        let amount1: BigNumber;

        describe("Amount lent > minBorrowAmount at the end of collection period", async () => {
            let poolStrategy: IYield;
            beforeEach(async () => {
                let deployHelper: DeployHelper = new DeployHelper(borrower);
                collateralToken = await deployHelper.mock.getMockERC20(
                    Contracts.DAI
                );
    
                borrowToken = await deployHelper.mock.getMockERC20(
                    Contracts.LINK
                );
                poolStrategy = await deployHelper.mock.getYield(compoundYield.address);
    
                const salt = sha256(Buffer.from("borrower"+Math.random()*10000000));
    
                let generatedPoolAddress: Address = await getPoolAddress(
                    borrower.address,
                    Contracts.LINK,
                    Contracts.DAI,
                    poolStrategy.address,
                    poolFactory.address,
                    salt,
                    poolImpl.address,
                    false
                );
    
                const nonce = (await poolFactory.provider.getTransactionCount(poolFactory.address)) + 1;
                let newPoolToken: string = getContractAddress({
                    from: poolFactory.address,
                    nonce,
                });
    
                let {
                    _poolSize,
                    _minborrowAmount,
                    _collateralRatio,
                    _borrowRate,
                    _repaymentInterval,
                    _noOfRepaymentIntervals,
                    _collateralAmount,
                } = createPoolParams;
                await collateralToken
                    .connect(admin)
                    .transfer(borrower.address, _collateralAmount); // Transfer quantity to borrower
    
                await collateralToken.connect(borrower).approve(
                    generatedPoolAddress,
                    _collateralAmount
                );
    
                await poolFactory
                    .connect(borrower)
                    .createPool(
                        _poolSize,
                        _minborrowAmount,
                        Contracts.LINK,
                        Contracts.DAI,
                        _collateralRatio,
                        _borrowRate,
                        _repaymentInterval,
                        _noOfRepaymentIntervals,
                        poolStrategy.address,
                        _collateralAmount,
                        false,
                        salt
                    );
    
                poolToken = await deployHelper.pool.getPoolToken(
                    newPoolToken
                );
    
                pool = await deployHelper.pool.getPool(generatedPoolAddress);

                amount = createPoolParams._minborrowAmount.add(100).mul(2).div(3);
                amount1 = createPoolParams._minborrowAmount.add(100).div(3);
                await borrowToken.connect(admin).transfer(
                    lender.address,
                    amount
                );
                await borrowToken.connect(lender).approve(
                    pool.address,
                    amount
                );
                await pool.connect(lender).lend(lender.address, amount, false);

                await borrowToken.connect(admin).transfer(
                    lender1.address,
                    amount1
                );
                await borrowToken.connect(lender1).approve(
                    pool.address,
                    amount1
                );
                await pool.connect(lender1).lend(lender1.address, amount1, false);

                const { loanStartTime } = await pool.poolConstants();
                await blockTravel(network, parseInt(loanStartTime.add(1).toString()));
                await pool.connect(borrower).withdrawBorrowedAmount();
                const { loanStatus } = await pool.poolVars();
                assert(loanStatus == 1, "Loan is not active");
            });

            it("Lender tokens should be transferable", async () => {
                const lenderBal = await poolToken.balanceOf(lender.address);
                const randomBal = await poolToken.balanceOf(random.address);
                
                const transferAmount = lenderBal.div(2);
                await poolToken.connect(lender).transfer(random.address, transferAmount);
                
                const lenderBalAfter = await poolToken.balanceOf(lender.address);
                const randomBalAfter = await poolToken.balanceOf(random.address);

                assert(
                    lenderBal.sub(lenderBalAfter).toString() == transferAmount.toString(),
                    `lender tokens not correctly deducted from sender`
                );
                assert(
                    randomBalAfter.sub(randomBal).toString() == transferAmount.toString(),
                    `lender tokens not correctly received by receiver`
                );
            });

            it("Borrower can't withdraw again", async () => {
                await expect(
                    pool.connect(borrower).withdrawBorrowedAmount()
                ).to.be.revertedWith("12");
            });

            it("Pool cannot be cancelled by anyone", async () => {
                await expect(
                    pool.connect(borrower).cancelPool()
                ).to.be.revertedWith("CP1");

                await expect(
                    pool.connect(lender).cancelPool()
                ).to.be.revertedWith("CP1");

                await expect(
                    pool.connect(random).cancelPool()
                ).to.be.revertedWith("CP1");
            });

            context("Borrower should repay interest", async () => {
                it("Repay interest for first  repay period", async () => {
                    const repayAmount = createPoolParams._borrowRate.mul(createPoolParams._borrowAmountRequested).mul(createPoolParams._repaymentInterval).div(60*60*24*356).div(BigNumber.from(10).pow(30))
                    const interestForCurrentPeriod = await repaymentImpl.getInterestDueTillInstalmentDeadline(pool.address);
                    assert(
                        interestForCurrentPeriod.toString() == repayAmount.toString(),
                        `Incorrect interest for period 1. Actual: ${interestForCurrentPeriod.toString()} Expected: ${repayAmount.toString()}`
                    );
                    await borrowToken.connect(random).approve(repaymentImpl.address, repayAmount);
                    await repaymentImpl.connect(random).repayAmount(pool.address, repayAmount);
                });

                it("Can repay for second repayment period in first repay period", async () => {
                    const repayAmount = createPoolParams._borrowRate.mul(createPoolParams._borrowAmountRequested).mul(createPoolParams._repaymentInterval).div(60*60*24*356).div(BigNumber.from(10).pow(30))
                    
                    await borrowToken.connect(random).approve(repaymentImpl.address, repayAmount.add(10));
                    await repaymentImpl.connect(random).repayAmount(pool.address, repayAmount.add(10));
                });  

                it("Repay in grace period, with penality", async () => {
                    const endOfPeriod:BigNumber = await repaymentImpl.getNextInstalmentDeadline(pool.address);
                    const gracePeriod:BigNumber = repaymentParams.gracePeriodFraction.mul(createPoolParams._repaymentInterval).div(BigNumber.from(10).pow(30));

                    await timeTravel(network, parseInt(endOfPeriod.add(gracePeriod).sub(10).toString()));

                    const repayAmount = createPoolParams._borrowRate.mul(createPoolParams._borrowAmountRequested).mul(createPoolParams._repaymentInterval).div(60*60*24*356).div(BigNumber.from(10).pow(30))
                    const repayAmountWithPenality = repayAmount.add(repaymentParams.gracePenalityRate.mul(await repaymentImpl.getInterestLeft(pool.address)));
                    await borrowToken.connect(random).approve(repaymentImpl.address, repayAmountWithPenality);
                    await expect(
                        repaymentImpl.connect(random).repayAmount(pool.address, repayAmount)
                    ).to.be.revertedWith("");
                    await repaymentImpl.connect(random).repayAmount(pool.address, repayAmountWithPenality);
                });

                it("Repay for next period after repayment in grace period", async () => {
                    const endOfPeriod:BigNumber = await repaymentImpl.getNextInstalmentDeadline(pool.address);
                    const gracePeriod:BigNumber = repaymentParams.gracePeriodFraction.mul(createPoolParams._repaymentInterval).div(BigNumber.from(10).pow(30));

                    await timeTravel(network, parseInt(endOfPeriod.add(gracePeriod).sub(10).toString()));

                    const repayAmount = createPoolParams._borrowRate.mul(createPoolParams._borrowAmountRequested).mul(createPoolParams._repaymentInterval).div(60*60*24*356).div(BigNumber.from(10).pow(30))
                    const repayAmountWithPenality = repayAmount.add(repaymentParams.gracePenalityRate.mul(await repaymentImpl.getInterestLeft(pool.address)));
                    await borrowToken.connect(random).approve(repaymentImpl.address, repayAmountWithPenality);
                    await repaymentImpl.connect(random).repayAmount(pool.address, repayAmountWithPenality.add(20));
                    const interestForCurrentPeriod = await repaymentImpl.getInterestDueTillInstalmentDeadline(pool.address);
                    assert(
                        interestForCurrentPeriod.toString() == repayAmount.sub(20).toString(),
                        `Extra repayment in grace period not correctly recorded. Actual: ${interestForCurrentPeriod.toString()} Expected: ${repayAmount.sub(20)}`
                    );
                });

                it("Can't liquidate in grace period", async () => {
                    const endOfPeriod:BigNumber = await repaymentImpl.getNextInstalmentDeadline(pool.address);

                    await timeTravel(network, parseInt(endOfPeriod.add(10).toString()));

                    await expect(
                        pool.liquidatePool(false, false, false)
                    ).to.be.revertedWith("Pool::liquidatePool - No reason to liquidate the pool");
                });
            });

            context("Borrower requests extension", async () => {
                it("Request extension", async () => {
                    await extenstion.requestExtension(pool.address);
                });
                
                it("Extension passed", async () => {
                    await extenstion.requestExtension(pool.address);
                    await extenstion.connect(lender).voteOnExtension(pool.address);
                    await extenstion.connect(lender1).voteOnExtension(pool.address);
                });

                context("Extension passed", async () => {
                    it("Shouldn't be liquidated for current period", async () => {
                    
                    });

                    it("liquidate if repay less than interest for extended period", async () => {
                    
                    });

                    it("Can't liquidate if repay is more than interest for extended period", async () => {
                    
                    });

                    it("Repay interest for period after extension", async () => {
                    
                    });
                });
                
                context("Extension failed", async () => {
                    it("Shouldn't be liquidated for current period if interest is repaid", async () => {
                    
                    });

                    it("liquidate if repay is less than interest for current period", async () => {
                    
                    });
                });
    
                context("Extension passed exactly with cutoff ", async () => {
                    it("Shouldn't be liquidated for current period", async () => {
                    
                    });

                    it("liquidate if repay less than interest for extended period", async () => {
                    
                    });

                    it("Can't liquidate if repay is more than interest for extended period", async () => {
                    
                    });

                    it("Repay interest for period after extension", async () => {
                    
                    });
                });

                context("Can't request another extension",  async () => {
                    it("when extension is requested", async () => {

                    });
    
                    it("after an extension passed", async () => {
    
                    });
    
                    it("after an extension passed and extended period is complete", async () => {
    
                    });
                });
            });

            context("Borrower defaulted repayment", async () => {
                it("Liquidate pool", async () => {
                    
                });
                
                it("Lenders should be able to withdraw repayments till now", async () => {
                    
                });
    
                it("Lenders should be able to withdraw liquidated collateral", async () => {
                    
                });

                it("Borrower can't withdraw collateral", async () => {

                });
            });

            context("Margin call when collateral ratio falls below ideal ratio", async () => {
                it("Margin called lender, can't send pool tokens", async () => {

                });

                it("Margin called lender, can't receive pool tokens", async () => {

                });

                it("Any lender can initiate margin call", async () => {
                
                });
                
                it("Margin call can't be liquidated, if borrower adds collateral for margin call", async () => {
                    
                });
    
                it("Margin call can't be liquidated, if collateral ratio goes above ideal ratio", async () => {
                    
                });
    
                it("If collateral ratio below ideal after margin call time, Anyone can liquidate lender's part of collateral", async () => {
                    
                });

                context("Collateral added in margin call is specific to lender", async () => {
                    it("If pool liquidated, lender for whom collateral was added in margin call should get extra collateral", async () => {

                    });
                });
            });
        });
    });
});