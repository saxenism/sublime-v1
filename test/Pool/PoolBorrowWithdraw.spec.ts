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

describe("Pool Borrow Withdrawal stage", async () => {
    let savingsAccount: SavingsAccount;
    let strategyRegistry: StrategyRegistry;

    let mockCreditLines: SignerWithAddress;
    let proxyAdmin: SignerWithAddress;
    let admin: SignerWithAddress;
    let borrower: SignerWithAddress;
    let lender: SignerWithAddress;
    let lender1: SignerWithAddress;

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
        [proxyAdmin, admin, mockCreditLines, borrower, lender, lender1] = await ethers.getSigners();
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
                Contracts.DAI,
                ChainLinkAggregators["LINK/USD"],
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

        await repaymentImpl.connect(admin).initialize(admin.address, poolFactory.address, repaymentParams.votingPassRatio, savingsAccount.address);

        await poolFactory
            .connect(admin)
            .setImplementations(
                poolImpl.address,
                repaymentImpl.address,
                poolTokenImpl.address
            );
    });

    describe("Pool that borrows ERC20 with ERC20 as collateral", async () => {
        let pool: Pool;
        let poolToken: PoolToken;
        let collateralToken: ERC20;
        let borrowToken: ERC20;

        describe("Amount lent < minBorrowAmount at the end of collection period", async () => {
            beforeEach(async () => {
                let deployHelper: DeployHelper = new DeployHelper(borrower);
                collateralToken = await deployHelper.mock.getMockERC20(
                    Contracts.DAI
                );
    
                borrowToken = await deployHelper.mock.getMockERC20(
                    Contracts.LINK
                );
    
                const salt = sha256(Buffer.from("borrower"+Math.random()*10000000));
    
                let generatedPoolAddress: Address = await getPoolAddress(
                    borrower.address,
                    Contracts.LINK,
                    Contracts.DAI,
                    compoundYield.address,
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
                        compoundYield.address,
                        _collateralAmount,
                        false,
                        salt
                    );
    
                poolToken = await deployHelper.pool.getPoolToken(
                    newPoolToken
                );
    
                pool = await deployHelper.pool.getPool(generatedPoolAddress);

                const amount = createPoolParams._minborrowAmount.sub(10);
                await borrowToken.connect(admin).transfer(
                    lender.address,
                    amount
                );
                await borrowToken.connect(lender).approve(
                    pool.address,
                    amount
                );
                await pool.connect(lender).lend(lender.address, amount, false);

                const { loanStartTime } = await pool.poolConstants();
                await blockTravel(network, parseInt(loanStartTime.add(1).toString()));
            });

            it("Lender pool tokens should be transferrable", async () => {
                const balance = await poolToken.balanceOf(lender.address);
                const balanceBefore = await poolToken.balanceOf(lender1.address);
                await poolToken.connect(lender).transfer(lender1.address, balance);
                const balanceAfter = await poolToken.balanceOf(lender1.address);
                assert(balanceBefore.add(balance).toString() == balanceAfter.toString(), "Pool token transfer not working");
                const balanceSenderAfter = await poolToken.balanceOf(lender.address);
                assert(balanceSenderAfter.toString() == "0", `Pool token not getting transferred correctly. Expected: 0, actual: ${balanceSenderAfter.toString()}`);
            });

            it("Lender cannot withdraw tokens", async () => {
                await expect(
                    pool.connect(lender).withdrawLiquidity()
                ).to.revertedWith("24");
            });

            it("Borrower can't withdraw", async () => {
                await expect(
                    pool.connect(lender).withdrawBorrowedAmount()
                ).to.revertedWith("");
            });
        })

        describe("Amount lent > minBorrowAmount at the end of collection period", async () => {
            beforeEach(async () => {
                let deployHelper: DeployHelper = new DeployHelper(borrower);
                collateralToken = await deployHelper.mock.getMockERC20(
                    Contracts.DAI
                );
    
                borrowToken = await deployHelper.mock.getMockERC20(
                    Contracts.LINK
                );
    
                const salt = sha256(Buffer.from("borrower"+Math.random()*10000000));
    
                let generatedPoolAddress: Address = await getPoolAddress(
                    borrower.address,
                    Contracts.LINK,
                    Contracts.DAI,
                    compoundYield.address,
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
    
                await expect(
                    poolFactory
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
                            compoundYield.address,
                            _collateralAmount,
                            false,
                            salt
                        )
                )
                .to.emit(poolFactory, "PoolCreated")
                .withArgs(generatedPoolAddress, borrower.address, newPoolToken);
    
                poolToken = await deployHelper.pool.getPoolToken(
                    newPoolToken
                );
    
                pool = await deployHelper.pool.getPool(generatedPoolAddress);

                const amount = createPoolParams._minborrowAmount.add(10);
                await borrowToken.connect(admin).transfer(
                    lender.address,
                    amount
                );
                await borrowToken.connect(lender).approve(
                    pool.address,
                    amount
                );
                await pool.connect(lender).lend(lender.address, amount, false);

                const { loanStartTime } = await pool.poolConstants();
                await blockTravel(network, parseInt(loanStartTime.add(1).toString()));
            });

            it("Lender pool tokens should be transferrable", async () => {
                const balance = await poolToken.balanceOf(lender.address);
                const balanceBefore = await poolToken.balanceOf(lender1.address);
                await poolToken.connect(lender).transfer(lender1.address, balance);
                const balanceAfter = await poolToken.balanceOf(lender1.address);
                assert(balanceBefore.add(balance).toString() == balanceAfter.toString(), "Pool token transfer not working");
                const balanceSenderAfter = await poolToken.balanceOf(lender.address);
                assert(balanceSenderAfter.toString() == "0", `Pool token not getting transferred correctly. Expected: 0, actual: ${balanceSenderAfter.toString()}`);
            });

            it("Lender cannot withdraw tokens", async () => {
                await expect(
                    pool.connect(lender).withdrawLiquidity()
                ).to.revertedWith("24");
            });

            it("Borrower can withdraw", async () => {
                const borrowAssetBalanceBorrower = await borrowToken.balanceOf(borrower.address);
                const borrowAssetBalancePool = await borrowToken.balanceOf(pool.address);
                const borrowAssetBalancePoolSavings = await savingsAccount.userLockedBalance(pool.address, borrowToken.address, zeroAddress);
                const tokensLent = await poolToken.totalSupply();
                await pool.connect(borrower).withdrawBorrowedAmount();
                const borrowAssetBalanceBorrowerAfter = await borrowToken.balanceOf(borrower.address);
                const borrowAssetBalancePoolAfter = await borrowToken.balanceOf(pool.address);
                const borrowAssetBalancePoolSavingsAfter = await savingsAccount.userLockedBalance(pool.address, borrowToken.address, zeroAddress);
                const tokensLentAfter = await poolToken.totalSupply();

                assert(
                    tokensLent.toString() == tokensLentAfter.toString(), 
                    "Tokens lent changing while withdrawing borrowed amount"
                );
                assert(
                    borrowAssetBalanceBorrower.add(tokensLent).toString() == borrowAssetBalanceBorrowerAfter.toString(), 
                    "Borrower not receiving correct lent amount"
                );
                assert(
                    borrowAssetBalancePool.toString() == borrowAssetBalancePoolAfter.toString(), 
                    "Pool token balance is changing instead of savings account balance"
                );
                assert(
                    borrowAssetBalancePoolSavings.toString() == borrowAssetBalancePoolSavingsAfter.add(tokensLentAfter).toString(), 
                    `Savings account balance of pool not changing correctly. Expected: ${borrowAssetBalancePoolSavingsAfter.toString()} Actual: ${borrowAssetBalancePoolSavings.sub(tokensLentAfter).toString()}`
                );
            });
        })

        describe("Amount lent == minBorrowAmount at the end of collection period", async () => {
            beforeEach(async () => {
                let deployHelper: DeployHelper = new DeployHelper(borrower);
                collateralToken = await deployHelper.mock.getMockERC20(
                    Contracts.DAI
                );
    
                borrowToken = await deployHelper.mock.getMockERC20(
                    Contracts.LINK
                );
    
                const salt = sha256(Buffer.from("borrower"+Math.random()*10000000));
    
                let generatedPoolAddress: Address = await getPoolAddress(
                    borrower.address,
                    Contracts.LINK,
                    Contracts.DAI,
                    compoundYield.address,
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
    
                await expect(
                    poolFactory
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
                            compoundYield.address,
                            _collateralAmount,
                            false,
                            salt
                        )
                )
                .to.emit(poolFactory, "PoolCreated")
                .withArgs(generatedPoolAddress, borrower.address, newPoolToken);
    
                poolToken = await deployHelper.pool.getPoolToken(
                    newPoolToken
                );
    
                pool = await deployHelper.pool.getPool(generatedPoolAddress);

                const amount = createPoolParams._minborrowAmount;
                await borrowToken.connect(admin).transfer(
                    lender.address,
                    amount
                );
                await borrowToken.connect(lender).approve(
                    pool.address,
                    amount
                );
                await pool.connect(lender).lend(lender.address, amount, false);

                const { loanStartTime } = await pool.poolConstants();
                await blockTravel(network, parseInt(loanStartTime.add(1).toString()));
            });

            it("Lender pool tokens should be transferrable", async () => {
                const balance = await poolToken.balanceOf(lender.address);
                const balanceBefore = await poolToken.balanceOf(lender1.address);
                await poolToken.connect(lender).transfer(lender1.address, balance);
                const balanceAfter = await poolToken.balanceOf(lender1.address);
                assert(balanceBefore.add(balance).toString() == balanceAfter.toString(), "Pool token transfer not working");
                const balanceSenderAfter = await poolToken.balanceOf(lender.address);
                assert(balanceSenderAfter.toString() == "0", `Pool token not getting transferred correctly. Expected: 0, actual: ${balanceSenderAfter.toString()}`);
            });

            it("Lender cannot withdraw tokens", async () => {
                await expect(
                    pool.connect(lender).withdrawLiquidity()
                ).to.revertedWith("24");
            });

            it("Borrower can withdraw", async () => {
                const borrowAssetBalanceBorrower = await borrowToken.balanceOf(borrower.address);
                const borrowAssetBalancePool = await borrowToken.balanceOf(pool.address);
                const borrowAssetBalancePoolSavings = await savingsAccount.userLockedBalance(pool.address, borrowToken.address, zeroAddress);
                const tokensLent = await poolToken.totalSupply();
                await pool.connect(borrower).withdrawBorrowedAmount();
                const borrowAssetBalanceBorrowerAfter = await borrowToken.balanceOf(borrower.address);
                const borrowAssetBalancePoolAfter = await borrowToken.balanceOf(pool.address);
                const borrowAssetBalancePoolSavingsAfter = await savingsAccount.userLockedBalance(pool.address, borrowToken.address, zeroAddress);
                const tokensLentAfter = await poolToken.totalSupply();

                assert(
                    tokensLent.toString() == tokensLentAfter.toString(), 
                    "Tokens lent changing while withdrawing borrowed amount"
                );
                assert(tokensLent.toString() == createPoolParams._minborrowAmount.toString(), "TokensLent is not same as minBorrowAmount");
                assert(borrowAssetBalanceBorrower.add(tokensLent).toString() == borrowAssetBalanceBorrowerAfter.toString(), "Borrower not receiving correct lent amount");
                assert(borrowAssetBalancePool.toString() == borrowAssetBalancePoolAfter.toString(), "Pool token balance is changing instead of savings account balance");
                assert(borrowAssetBalancePoolSavings.toString() == borrowAssetBalancePoolSavingsAfter.add(tokensLentAfter).toString(), "Savings account balance of pool not changing correctly");
            });
        })

        describe("Amount lent == amountRequested at the end of collection period", async () => {
            beforeEach(async () => {
                let deployHelper: DeployHelper = new DeployHelper(borrower);
                collateralToken = await deployHelper.mock.getMockERC20(
                    Contracts.DAI
                );
    
                borrowToken = await deployHelper.mock.getMockERC20(
                    Contracts.LINK
                );
    
                const salt = sha256(Buffer.from("borrower"+Math.random()*10000000));
    
                let generatedPoolAddress: Address = await getPoolAddress(
                    borrower.address,
                    Contracts.LINK,
                    Contracts.DAI,
                    compoundYield.address,
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
    
                await expect(
                    poolFactory
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
                            compoundYield.address,
                            _collateralAmount,
                            false,
                            salt
                        )
                )
                .to.emit(poolFactory, "PoolCreated")
                .withArgs(generatedPoolAddress, borrower.address, newPoolToken);
    
                poolToken = await deployHelper.pool.getPoolToken(
                    newPoolToken
                );
    
                pool = await deployHelper.pool.getPool(generatedPoolAddress);

                const amount = createPoolParams._borrowAmountRequested;
                await borrowToken.connect(admin).transfer(
                    lender.address,
                    amount
                );
                await borrowToken.connect(lender).approve(
                    pool.address,
                    amount
                );
                await pool.connect(lender).lend(lender.address, amount, false);
                console.log("lender balance", (await poolToken.balanceOf(lender.address)).toString(), amount.toString());

                const { loanStartTime } = await pool.poolConstants();
                await blockTravel(network, parseInt(loanStartTime.add(1).toString()));
            });

            it("Lender pool tokens should be transferrable", async () => {
                const balance = await poolToken.balanceOf(lender.address);
                const balanceBefore = await poolToken.balanceOf(lender1.address);
                await poolToken.connect(lender).transfer(lender1.address, balance);
                const balanceAfter = await poolToken.balanceOf(lender1.address);
                assert(balanceBefore.add(balance).toString() == balanceAfter.toString(), "Pool token transfer not working");
                const balanceSenderAfter = await poolToken.balanceOf(lender.address);
                assert(balanceSenderAfter.toString() == "0", `Pool token not getting transferred correctly. Expected: 0, actual: ${balanceSenderAfter.toString()}`);
            });

            it("Lender cannot withdraw tokens", async () => {
                await expect(
                    pool.connect(lender).withdrawLiquidity()
                ).to.revertedWith("24");
            });

            it("Borrower can withdraw", async () => {
                const borrowAssetBalanceBorrower = await borrowToken.balanceOf(borrower.address);
                const borrowAssetBalancePool = await borrowToken.balanceOf(pool.address);
                const borrowAssetBalancePoolSavings = await savingsAccount.userLockedBalance(pool.address, borrowToken.address, zeroAddress);
                const tokensLent = await poolToken.totalSupply();
                await pool.connect(borrower).withdrawBorrowedAmount();
                const borrowAssetBalanceBorrowerAfter = await borrowToken.balanceOf(borrower.address);
                const borrowAssetBalancePoolAfter = await borrowToken.balanceOf(pool.address);
                const borrowAssetBalancePoolSavingsAfter = await savingsAccount.userLockedBalance(pool.address, borrowToken.address, zeroAddress);
                const tokensLentAfter = await poolToken.totalSupply();

                assert(
                    tokensLent.toString() == tokensLentAfter.toString(), 
                    "Tokens lent changing while withdrawing borrowed amount"
                );
                assert(borrowAssetBalanceBorrower.add(tokensLent).toString() == borrowAssetBalanceBorrowerAfter.toString(), "Borrower not receiving correct lent amount");
                assert(borrowAssetBalancePool.toString() == borrowAssetBalancePoolAfter.toString(), "Pool token balance is changing instead of savings account balance");
                assert(borrowAssetBalancePoolSavings.toString() == borrowAssetBalancePoolSavingsAfter.add(tokensLentAfter).toString(), "Savings account balance of pool not changing correctly");
            });
        })
    });
});