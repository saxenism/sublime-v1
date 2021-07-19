import hre from 'hardhat';
import { contracts } from './contractsToVerify';

async function verifyProxy() {
    let [proxyAdmin] = await hre.ethers.getSigners();

    console.log(`Verifying contracts on network ${hre.network.name}`);

    console.log(`Verifying strategy proxy ${contracts.strategyRegistry.proxy}`);
    await hre.run('verify:verify', {
        address: contracts.strategyRegistry.proxy,
        constructorArguments: [contracts.strategyRegistry.logic, proxyAdmin.address, Buffer.from('')],
        contract: 'contracts/Proxy.sol:SublimeProxy',
    });

    // you don't need to verify all proxies. If needed, just copy the code snippet above
    return 'Proxy Verified';
}

async function verifyLogic() {
    console.log(`Verifying strategy logic ${contracts.strategyRegistry.logic}`);
    await hre.run('verify:verify', {
        address: contracts.strategyRegistry.logic,
        constructorArguments: [],
        contract: 'contracts/yield/StrategyRegistry.sol:StrategyRegistry',
    });

    console.log(`Verifying credit lines logic ${contracts.creditLines.logic}`);
    await hre.run('verify:verify', {
        address: contracts.creditLines.logic,
        constructorArguments: [],
        contract: 'contracts/CreditLine/CreditLine.sol:CreditLine',
    });

    console.log(`Verifying savings account logic ${contracts.savingsAccount.logic}`);
    await hre.run('verify:verify', {
        address: contracts.savingsAccount.logic,
        constructorArguments: [],
        contract: 'contracts/SavingsAccount/SavingsAccount.sol:SavingsAccount',
    });

    console.log(`Verifying aave yield logic ${contracts.aaveYield.logic}`);
    await hre.run('verify:verify', {
        address: contracts.aaveYield.logic,
        constructorArguments: [],
        contract: 'contracts/yield/AaveYield.sol:AaveYield',
    });

    console.log(`Verifying yearn yield logic ${contracts.yearnYield.logic}`);
    await hre.run('verify:verify', {
        address: contracts.yearnYield.logic,
        constructorArguments: [],
        contract: 'contracts/yield/YearnYield.sol:YearnYield',
    });

    console.log(`Verifying compound yield logic ${contracts.compoundYield.logic}`);
    await hre.run('verify:verify', {
        address: contracts.compoundYield.logic,
        constructorArguments: [],
        contract: 'contracts/yield/CompoundYield.sol:CompoundYield',
    });

    console.log(`Verifying price oracle logic ${contracts.priceOracle.logic}`);
    await hre.run('verify:verify', {
        address: contracts.priceOracle.logic,
        constructorArguments: [],
        contract: 'contracts/PriceOracle.sol:PriceOracle',
    });

    console.log(`Verifying verification logic ${contracts.verification.logic}`);
    await hre.run('verify:verify', {
        address: contracts.verification.logic,
        constructorArguments: [],
        contract: 'contracts/Verification/Verification.sol:Verification',
    });

    console.log(`Verifying pool factory logic ${contracts.poolFactory.logic}`);
    await hre.run('verify:verify', {
        address: contracts.poolFactory.logic,
        constructorArguments: [],
        contract: 'contracts/Pool/PoolFactory.sol:PoolFactory',
    });

    console.log(`Verifying repayments logic ${contracts.repayments.logic}`);
    await hre.run('verify:verify', {
        address: contracts.repayments.logic,
        constructorArguments: [],
        contract: 'contracts/Repayments/Repayments.sol:Repayments',
    });

    console.log(`Verifying extenstions logic ${contracts.extension.logic}`);
    await hre.run('verify:verify', {
        address: contracts.extension.logic,
        constructorArguments: [],
        contract: 'contracts/Pool/Extension.sol:Extension',
    });

    console.log(`Verifying pool logic ${contracts.pool.logic}`);
    await hre.run('verify:verify', {
        address: contracts.pool.logic,
        constructorArguments: [],
        contract: 'contracts/Pool/Pool.sol:Pool',
    });

    console.log(`Verifying pool token logic ${contracts.poolToken.logic}`);
    await hre.run('verify:verify', {
        address: contracts.poolToken.logic,
        constructorArguments: [],
        contract: 'contracts/Pool/PoolToken.sol:PoolToken',
    });

    return 'Logic Verified';
}

async function verify() {
    await verifyProxy();
    await verifyLogic();
    return 'All Verified';
}

verify().then(console.log).catch(console.log);
