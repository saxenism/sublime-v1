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

import { contracts } from './contractsToVerify';
import { zeroAddress, ChainLinkAggregators } from '../utils/constants';

import { Contracts } from '../existingContracts/compound.json';

// async function init(deployNetwork: string) {
//     if (allConfig.network != deployNetwork) {
//         console.error('Deploy network different from config network');
//         process.exit();
//     }

//     let config;
//     if (network.name.includes('kovan')) {
//         config = allConfig.kovan;
//     } else if (network.name.includes('mainnet')) {
//         config = allConfig.mainnet;
//     } else {
//         console.error('Config for network not found');
//         process.exit();
//     }
//     let [proxyAdmin, admin, deployer, verifier] = await ethers.getSigners();
//     const deployHelper: DeployHelper = new DeployHelper(deployer);

//     const strategyRegistry: StrategyRegistry = await deployHelper.core.getStrategyRegistry(contracts.strategyRegistry.proxy);
//     console.log(await strategyRegistry.maxStrategies()); // to check it connection is fine
//     // console.log(admin.address);
//     await strategyRegistry.connect(admin).addStrategy(contracts.aaveYield.proxy);
//     await strategyRegistry.connect(admin).addStrategy(contracts.compoundYield.proxy);
//     await strategyRegistry.connect(admin).addStrategy(contracts.yearnYield.proxy);
//     await strategyRegistry.connect(admin).addStrategy(zeroAddress);
//     return 'Done';
// }

// async function init(deployNetwork: string) {
//     if (allConfig.network != deployNetwork) {
//         console.error('Deploy network different from config network');
//         process.exit();
//     }

//     let config;
//     if (network.name.includes('kovan')) {
//         config = allConfig.kovan;
//     } else if (network.name.includes('mainnet')) {
//         config = allConfig.mainnet;
//     } else {
//         console.error('Config for network not found');
//         process.exit();
//     }
//     let [proxyAdmin, admin, deployer, verifier] = await ethers.getSigners();

//     const deployHelper: DeployHelper = new DeployHelper(deployer);
//     console.log(admin.address);

//     const priceOracle: PriceOracle = await deployHelper.helper.getPriceOracle(contracts.priceOracle.proxy);
//     console.log(await priceOracle.doesFeedExist([]));

//     await priceOracle
//         .connect(admin)
//         .setfeedAddress('0x463514ea551b88f176dc9e71e529dd02eb2d0cf8', '0x22B58f1EbEDfCA50feF632bD73368b2FdA96D541');
//     await priceOracle
//         .connect(admin)
//         .setfeedAddress('0xab2af84a9db35f92dfb5b0607bd91226f5e97469', '0x9326BFA02ADD2366b30bacB125260Af641031331');

//     return 'Done';
// }

// async function init(deployNetwork: string) {
//     if (allConfig.network != deployNetwork) {
//         console.error('Deploy network different from config network');
//         process.exit();
//     }

//     let config;
//     if (network.name.includes('kovan')) {
//         config = allConfig.kovan;
//     } else if (network.name.includes('mainnet')) {
//         config = allConfig.mainnet;
//     } else {
//         console.error('Config for network not found');
//         process.exit();
//     }
//     let [proxyAdmin, admin, deployer, verifier] = await ethers.getSigners();

//     const deployHelper: DeployHelper = new DeployHelper(deployer);
//     console.log(admin.address);
//     let verification: Verification = await deployHelper.helper.getVerification(contracts.verification.proxy);
//     await verification.connect(admin).registerUser('0xba4d24bb13e64a9404bfacf937cce6bb40a511ac', '0x1721b6a7f6c53368352bf227cbceb3b2b8b501c04f245247ef86a12ada4f4c63');
//     return 'Done';
// }

async function init(deployNetwork: string) {
    if (allConfig.network != deployNetwork) {
        console.error('Deploy network different from config network');
        process.exit();
    }

    let config;
    if (network.name.includes('kovan')) {
        config = allConfig.kovan;
    } else if (network.name.includes('mainnet')) {
        config = allConfig.mainnet;
    } else {
        console.error('Config for network not found');
        process.exit();
    }
    let [proxyAdmin, admin, deployer, verifier] = await ethers.getSigners();

    const deployHelper: DeployHelper = new DeployHelper(deployer);
    console.log(admin.address);
    let poolFactory: PoolFactory = await deployHelper.pool.getPoolFactory(contracts.poolFactory.proxy);
    await poolFactory.connect(admin).updateSupportedBorrowTokens('0x463514ea551b88f176dc9e71e529dd02eb2d0cf8', true);
    await poolFactory.connect(admin).updateSupportedBorrowTokens('0xab2af84a9db35f92dfb5b0607bd91226f5e97469', true);

    return "Done";
}

init('kovan').then(console.log);
