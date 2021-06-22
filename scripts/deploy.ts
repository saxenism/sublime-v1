import { ethers, network } from 'hardhat';

import DeployHelper from '../utils/deploys';
import allConfig from '../config/config.json';

import { SavingsAccount } from '../typechain/SavingsAccount';
import { StrategyRegistry } from '../typechain/StrategyRegistry';
import { AaveYield } from '../typechain/AaveYield';
import { YearnYield } from '../typechain/YearnYield';
import { CompoundYield } from '../typechain/CompoundYield';
import { Pool } from '../typechain/Pool';
import { Verification } from '../typechain/Verification';
import { PoolFactory } from '../typechain/PoolFactory';
import { ERC20 } from '../typechain/ERC20';
import { PriceOracle } from '../typechain/PriceOracle';
import { Extension } from '../typechain/Extension';

import { PoolToken } from '../typechain/PoolToken';
import { Repayments } from '../typechain/Repayments';
import { SublimeProxy } from '../typechain/SublimeProxy';
import { CreditLine } from '../typechain/CreditLine';

async function init(deployNetwork: string) {
    if(allConfig.network != deployNetwork) {
        console.error("Deploy network different from config network");
        process.exit();
    }

    let config;
    if(network.name.includes("kovan")) {
        config = allConfig.kovan;
    } else if(network.name.includes("mainnet")) {
        config = allConfig.mainnet
    } else {
        console.error("Config for network not found");
        process.exit();
    }
    let [
        proxyAdmin,
        admin,
        deployer,
        verifier
    ] = await ethers.getSigners();
    const deployHelper: DeployHelper = new DeployHelper(deployer);

    const strategyRegistryLogic: StrategyRegistry = await deployHelper.core.deployStrategyRegistry();
    const strategyRegistryProxy: SublimeProxy =  await deployHelper.helper.deploySublimeProxy(strategyRegistryLogic.address, proxyAdmin.address, Buffer.from(''));
    const strategyRegistry: StrategyRegistry = await deployHelper.core.getStrategyRegistry(strategyRegistryProxy.address);
    await strategyRegistry.initialize(admin.address, config.strategies.max);

    const creditLinesLogic: CreditLine = await deployHelper.core.deployCreditLines();
    const creditLinesProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(creditLinesLogic.address, proxyAdmin.address, Buffer.from(''));
    const creditLines: CreditLine = await deployHelper.core.getCreditLines(creditLinesProxy.address);

    const savingsAccountLogic: SavingsAccount = await deployHelper.core.deploySavingsAccount();
    const savingsAccountProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(savingsAccountLogic.address, proxyAdmin.address, Buffer.from(''));
    const savingsAccount: SavingsAccount = await deployHelper.core.getSavingsAccount(savingsAccountProxy.address);
    await savingsAccount.initialize(admin.address, strategyRegistry.address, creditLines.address);

    const aaveYieldLogic: AaveYield = await deployHelper.core.deployAaveYield();
    const aaveYieldProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(aaveYieldLogic.address, proxyAdmin.address, Buffer.from(''));
    const aaveYield: AaveYield = await deployHelper.core.getAaveYield(aaveYieldProxy.address);
    await aaveYield.initialize(
        admin.address, 
        savingsAccount.address, 
        config.strategies.aave.wethGateway, 
        config.strategies.aave.protocolDataProvider, 
        config.strategies.aave.lendingPoolAddressesProvider
    );

    const compoundYieldLogic: CompoundYield = await deployHelper.core.deployCompoundYield();
    const compoundYieldProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(compoundYieldLogic.address, proxyAdmin.address, Buffer.from(''));
    const compoundYield: CompoundYield = await deployHelper.core.getCompoundYield(compoundYieldProxy.address);
    await compoundYield.initialize(
        admin.address,
        savingsAccount.address
    );

    const yearnYieldLogic: YearnYield = await deployHelper.core.deployYearnYield();
    const yearnYieldProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(yearnYieldLogic.address, proxyAdmin.address, Buffer.from(''));
    const yearnYield: YearnYield = await deployHelper.core.getYearnYield(yearnYieldProxy.address);
    await yearnYield.initialize(
        admin.address,
        savingsAccount.address
    );

    await strategyRegistry.connect(admin).addStrategy(aaveYield.address);
    await strategyRegistry.connect(admin).addStrategy(compoundYield.address);
    await strategyRegistry.connect(admin).addStrategy(yearnYield.address);

    const priceOracleLogic: PriceOracle = await deployHelper.helper.deployPriceOracle();
    const priceOracleProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(priceOracleLogic.address, proxyAdmin.address, Buffer.from(''));
    const priceOracle: PriceOracle = await deployHelper.helper.getPriceOracle(priceOracleProxy.address);
    await priceOracle.initialize(
        admin.address
    );

    const verificationLogic: Verification = await deployHelper.helper.deployVerification();
    const verificationProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(verificationLogic.address, proxyAdmin.address, Buffer.from(''));
    const verification: Verification = await deployHelper.helper.getVerification(verificationProxy.address);
    await verification.initialize(
        verifier.address
    );

    const poolFactoryLogic: PoolFactory = await deployHelper.pool.deployPoolFactory();
    const poolFactoryProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(poolFactoryLogic.address, proxyAdmin.address, Buffer.from(''));
    const poolFactory: PoolFactory = await deployHelper.pool.getPoolFactory(poolFactoryProxy.address);
    
    const repaymentsLogic: Repayments = await deployHelper.pool.deployRepayments();
    const repaymentsProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(repaymentsLogic.address, proxyAdmin.address, Buffer.from(''));
    const repayments: Repayments = await deployHelper.pool.getRepayments(repaymentsProxy.address);
    await repayments.initialize(
        admin.address,
        poolFactory.address,
        config.repayments.votingPassRatio,
        savingsAccount.address
    );

    const extensionLogic: Extension = await deployHelper.pool.deployExtenstion();
    const extensionProxy: SublimeProxy = await deployHelper.helper.deploySublimeProxy(extensionLogic.address, proxyAdmin.address, Buffer.from(''));
    const extension: Extension = await deployHelper.pool.getExtension(extensionProxy.address);
    await extension.initialize(
        poolFactory.address
    );

    const poolLogic: Pool = await deployHelper.pool.deployPool();

    const poolToken: PoolToken = await deployHelper.pool.deployPoolToken();

    await poolFactory.initialize(
        verification.address,
        strategyRegistry.address,
        admin.address,
        config.pool.collectionPeriod,
        config.pool.matchCollateralRatioInterval,
        config.pool.marginCallDuration,
        config.pool.collateralVolatilityThreshold,
        config.pool.gracePeriodPenaltyFraction,
        poolLogic.interface.getSighash("initialize"),
        poolToken.interface.getSighash("initialize(string,string,address)"),
        config.pool.liquidatorRewardFraction,
        priceOracle.address,
        savingsAccount.address,
        extension.address,
        config.pool.poolCancelPenalityFraction
    );

    await poolFactory.connect(admin).setImplementations(
        poolLogic.address,
        repayments.address,
        poolToken.address
    );

    await creditLines.initialize(
        config.creditLines.defaultStrategy,
        poolFactory.address,
        strategyRegistry.address
    );
}

init("kovan");