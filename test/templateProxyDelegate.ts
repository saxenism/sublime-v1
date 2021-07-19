import { ethers, network } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, BigNumberish } from '@ethersproject/bignumber';
import { expect } from 'chai';

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
    OperationalAmounts,
    extensionParams,
} from '../utils/constants';
import DeployHelper from '../utils/deploys';

import { SavingsAccount } from '../typechain/SavingsAccount';
import { StrategyRegistry } from '../typechain/StrategyRegistry';

import { getPoolAddress, getRandomFromArray, incrementChain } from '../utils/helpers';

import { Address } from 'hardhat-deploy/dist/types';
import { AaveYield } from '../typechain/AaveYield';
import { YearnYield } from '../typechain/YearnYield';
import { CompoundYield } from '../typechain/CompoundYield';
import { Pool } from '../typechain/Pool';
import { Verification } from '../typechain/Verification';
import { PoolFactory } from '../typechain/PoolFactory';
import { ERC20 } from '../typechain/ERC20';
import { PriceOracle } from '../typechain/PriceOracle';
import { Extension } from '../typechain/Extension';

import { Contracts } from '../existingContracts/compound.json';
import { sha256 } from '@ethersproject/sha2';
import { PoolToken } from '../typechain/PoolToken';
import { Repayments } from '../typechain/Repayments';
import { ContractTransaction } from '@ethersproject/contracts';
import { getContractAddress } from '@ethersproject/address';

import { SublimeProxy } from '../typechain/SublimeProxy';

describe.only('Template 2', async () => {
    let savingsAccount: SavingsAccount;
    let savingsAccountLogic: SavingsAccount;

    let strategyRegistry: StrategyRegistry;
    let strategyRegistryLogic: StrategyRegistry;

    let mockCreditLines: SignerWithAddress;
    let proxyAdmin: SignerWithAddress;
    let admin: SignerWithAddress;
    let borrower: SignerWithAddress;
    let lender: SignerWithAddress;

    let aaveYield: AaveYield;
    let aaveYieldLogic: AaveYield;

    let yearnYield: YearnYield;
    let yearnYieldLogic: YearnYield;

    let compoundYield: CompoundYield;
    let compoundYieldLogic: CompoundYield;

    let BatTokenContract: ERC20;
    let LinkTokenContract: ERC20;
    let DaiTokenContract: ERC20;

    let verificationLogic: Verification;
    let verification: Verification;

    let priceOracleLogic: PriceOracle;
    let priceOracle: PriceOracle;

    let Binance7: any;
    let WhaleAccount: any;

    let extenstionLogic: Extension;
    let extenstion: Extension;

    let poolLogic: Pool;
    let poolTokenLogic: PoolToken;
    let repaymentLogic: Repayments;

    let poolFactoryLogic: PoolFactory;
    let poolFactory: PoolFactory;

    let pool: Pool;

    before(async () => {
        [proxyAdmin, admin, mockCreditLines, borrower, lender] = await ethers.getSigners();
        let deployHelper: DeployHelper = new DeployHelper(proxyAdmin);
        savingsAccountLogic = await deployHelper.core.deploySavingsAccount();
        let savingsAccountProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(
            savingsAccountLogic.address,
            proxyAdmin.address
        );
        savingsAccount = await deployHelper.core.getSavingsAccount(savingsAccountProxy.address);

        strategyRegistryLogic = await deployHelper.core.deployStrategyRegistry();
        let strategyRegistryProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(
            strategyRegistryLogic.address,
            proxyAdmin.address
        );
        strategyRegistry = await deployHelper.core.getStrategyRegistry(strategyRegistryProxy.address);

        //initialize
        savingsAccount.connect(admin).initialize(admin.address, strategyRegistry.address, mockCreditLines.address);
        strategyRegistry.connect(admin).initialize(admin.address, 10);

        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [binance7],
        });

        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [whaleAccount],
        });

        await admin.sendTransaction({
            to: whaleAccount,
            value: ethers.utils.parseEther('100'),
        });

        Binance7 = await ethers.provider.getSigner(binance7);
        WhaleAccount = await ethers.provider.getSigner(whaleAccount);

        BatTokenContract = await deployHelper.mock.getMockERC20(Contracts.BAT);
        await BatTokenContract.connect(Binance7).transfer(admin.address, BigNumber.from('10').pow(23)); // 10,000 BAT tokens

        LinkTokenContract = await deployHelper.mock.getMockERC20(Contracts.LINK);
        await LinkTokenContract.connect(Binance7).transfer(admin.address, BigNumber.from('10').pow(23)); // 10,000 LINK tokens

        DaiTokenContract = await deployHelper.mock.getMockERC20(Contracts.DAI);
        await DaiTokenContract.connect(WhaleAccount).transfer(admin.address, BigNumber.from('10').pow(23)); // 10,000 DAI

        aaveYieldLogic = await deployHelper.core.deployAaveYield();
        let aaveYieldProxy = await deployHelper.helper.deploySublimeProxy(aaveYieldLogic.address, proxyAdmin.address);
        aaveYield = await deployHelper.core.getAaveYield(aaveYieldProxy.address);

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

        yearnYieldLogic = await deployHelper.core.deployYearnYield();
        let yearnYieldProxy = await deployHelper.helper.deploySublimeProxy(yearnYieldLogic.address, proxyAdmin.address);
        yearnYield = await deployHelper.core.getYearnYield(yearnYieldProxy.address);

        await yearnYield.connect(admin).initialize(admin.address, savingsAccount.address);
        await strategyRegistry.connect(admin).addStrategy(yearnYield.address);
        await yearnYield.connect(admin).updateProtocolAddresses(DaiTokenContract.address, DAI_Yearn_Protocol_Address);

        compoundYieldLogic = await deployHelper.core.deployCompoundYield();
        let compoundYieldProxy = await deployHelper.helper.deploySublimeProxy(compoundYieldLogic.address, proxyAdmin.address);
        compoundYield = await deployHelper.core.getCompoundYield(compoundYieldProxy.address);

        await compoundYield.connect(admin).initialize(admin.address, savingsAccount.address);
        await strategyRegistry.connect(admin).addStrategy(compoundYield.address);
        await compoundYield.connect(admin).updateProtocolAddresses(Contracts.DAI, Contracts.cDAI);

        verificationLogic = await deployHelper.helper.deployVerification();
        let verificationProxy = await deployHelper.helper.deploySublimeProxy(verificationLogic.address, proxyAdmin.address);
        verification = await deployHelper.helper.getVerification(verificationProxy.address);
        await verification.connect(admin).initialize(admin.address);
        await verification.connect(admin).registerUser(borrower.address, sha256(Buffer.from('Borrower')));

        priceOracleLogic = await deployHelper.helper.deployPriceOracle();
        let priceOracleProxy = await deployHelper.helper.deploySublimeProxy(priceOracleLogic.address, proxyAdmin.address);
        priceOracle = await deployHelper.helper.getPriceOracle(priceOracleProxy.address);
        await priceOracle.connect(admin).initialize(admin.address);
        await priceOracle.connect(admin).setfeedAddress(Contracts.LINK, ChainLinkAggregators['LINK/USD']);
        await priceOracle.connect(admin).setfeedAddress(Contracts.DAI, ChainLinkAggregators['DAI/USD']);

        poolFactoryLogic = await deployHelper.pool.deployPoolFactory();
        let poolFactoryProxy = await deployHelper.helper.deploySublimeProxy(poolFactoryLogic.address, proxyAdmin.address);
        poolFactory = await deployHelper.pool.getPoolFactory(poolFactoryProxy.address);

        extenstionLogic = await deployHelper.pool.deployExtenstion();
        let extenstionProxy = await deployHelper.helper.deploySublimeProxy(extenstionLogic.address, proxyAdmin.address);
        extenstion = await deployHelper.pool.getExtension(extenstionProxy.address);
        await extenstion.connect(admin).initialize(poolFactory.address, extensionParams.votingPassRatio);

        let {
            _collectionPeriod,
            _marginCallDuration,
            _collateralVolatilityThreshold,
            _gracePeriodPenaltyFraction,
            _liquidatorRewardFraction,
            _matchCollateralRatioInterval,
            _poolInitFuncSelector,
            _poolTokenInitFuncSelector,
            _poolCancelPenalityFraction,
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
        poolLogic = await deployHelper.pool.deployPool();
        poolTokenLogic = await deployHelper.pool.deployPoolToken();
        repaymentLogic = await deployHelper.pool.deployRepayments();

        await poolFactory.connect(admin).updateSupportedBorrowTokens(Contracts.DAI, true);

        await poolFactory.connect(admin).updateSupportedCollateralTokens(Contracts.LINK, true);

        await poolFactory.connect(admin).setImplementations(poolLogic.address, repaymentLogic.address, poolTokenLogic.address);

        deployHelper = new DeployHelper(borrower);
        let collateralToken: ERC20 = await deployHelper.mock.getMockERC20(Contracts.LINK);

        let generatedPoolAddress: Address = await getPoolAddress(
            borrower.address,
            Contracts.DAI,
            Contracts.LINK,
            aaveYield.address,
            poolFactory.address,
            sha256(Buffer.from('borrower')),
            poolLogic.address,
            false
        );

        const nonce = (await poolFactory.provider.getTransactionCount(poolFactory.address)) + 1;
        let newPoolToken: string = getContractAddress({
            from: poolFactory.address,
            nonce,
        });

        // console.log({
        //   generatedPoolAddress,
        //   msgSender: borrower.address,
        //   newPoolToken,
        //   savingsAccountFromPoolFactory: await poolFactory.savingsAccount(),
        //   savingsAccount: savingsAccount.address
        // });

        let { _poolSize, _minborrowAmount, _collateralRatio, _borrowRate, _repaymentInterval, _noOfRepaymentIntervals, _collateralAmount } =
            createPoolParams;

        await collateralToken.connect(admin).transfer(borrower.address, _collateralAmount.mul(2)); // Transfer quantity to borrower

        await collateralToken.approve(generatedPoolAddress, _collateralAmount.mul(2));

        await expect(
            poolFactory
                .connect(borrower)
                .createPool(
                    _poolSize,
                    _minborrowAmount,
                    Contracts.DAI,
                    Contracts.LINK,
                    _collateralRatio,
                    _borrowRate,
                    _repaymentInterval,
                    _noOfRepaymentIntervals,
                    aaveYield.address,
                    _collateralAmount,
                    false,
                    sha256(Buffer.from('borrower'))
                )
        )
            .to.emit(poolFactory, 'PoolCreated')
            .withArgs(generatedPoolAddress, borrower.address, newPoolToken);

        let newlyCreatedToken: PoolToken = await deployHelper.pool.getPoolToken(newPoolToken);

        expect(await newlyCreatedToken.name()).eq('Open Borrow Pool Tokens');
        expect(await newlyCreatedToken.symbol()).eq('OBPT');
        expect(await newlyCreatedToken.decimals()).eq(18);

        pool = await deployHelper.pool.getPool(generatedPoolAddress);
        await pool.connect(borrower).depositCollateral(_collateralAmount, false);
    });

    it('Print Add Addresses', async () => {
        console.log({
            savingsAccount: savingsAccount.address,
            savingsAccountLogic: savingsAccountLogic.address,
            strategyRegistry: strategyRegistry.address,
            strategyRegistryLogic: strategyRegistryLogic.address,
            mockCreditLines: mockCreditLines.address,
            proxyAdmin: proxyAdmin.address,
            admin: admin.address,
            borrower: borrower.address,
            lender: lender.address,
            aaveYield: aaveYield.address,
            aaveYieldLogic: aaveYieldLogic.address,
            yearnYield: yearnYield.address,
            yearnYieldLogic: yearnYieldLogic.address,
            compoundYield: compoundYield.address,
            compoundYieldLogic: compoundYieldLogic.address,
            verificationLogic: verificationLogic.address,
            verification: verification.address,
            priceOracleLogic: priceOracleLogic.address,
            priceOracle: priceOracle.address,
            extenstionLogic: extenstionLogic.address,
            extenstion: extenstion.address,
            poolLogic: poolLogic.address,
            poolTokenLogic: poolTokenLogic.address,
            repaymentLogic: repaymentLogic.address,
            poolFactoryLogic: poolFactoryLogic.address,
            poolFactory: poolFactory.address,
            pool: pool.address,
        });
    });
});
