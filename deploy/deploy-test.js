const Web3 = require('web3')
const fs = require('fs')
const allConfigs = require('../config/config.json')
const keystore = require('../keystore/keystore.json')

const proxyCompiled = require('../build/contracts/SublimeProxy.json')

const tokenCompiled = require('../build/contracts/Token.json')
const aaveYieldCompiled = require('../build/contracts/AaveYield.json')
const compoundYieldCompiled = require('../build/contracts/CompoundYield.json')
const yearnYieldCompiled = require('../build/contracts/YearnYield.json')
const strategyRegistryCompiled = require('../build/contracts/StrategyRegistry.json')
const savingsAccountCompiled = require('../build/contracts/SavingsAccount.json')
const priceOracleCompiled = require('../build/contracts/PriceOracle.json')
const verificationCompiled = require('../build/contracts/Verification.json')
const repaymentsCompiled = require('../build/contracts/Repayments.json')
const extensionCompiled = require('../build/contracts/Extension.json')
const poolFactoryCompiled = require('../build/contracts/PoolFactory.json')
const creditLinesCompiled = require('../build/contracts/CreditLine.json')
const poolCompiled = require('../build/contracts/Pool.json')

const utils = require('./utils')

const config = allConfigs['ganache']
let web3 = new Web3(config.blockchain.url)

const deploy = async () => {
  const accounts = await web3.eth.getAccounts()
  const proxyAdmin = accounts[0]
  const admin = accounts[1]
  const deployer = accounts[2]

  const deploymentConfig = {
    from: deployer,
    gas: config.tx.gas,
    gasPrice: config.tx.gasPrice,
  }

  const adminDeploymentConfig = {
    from: admin,
    gas: config.tx.gas,
    gasPrice: config.tx.gasPrice,
  }

  // deploy strategy Registry
  const strategyRegistryInitParams = [admin, config.strategies.max]
  const strategyRegistry = await utils.deployWithProxy(
    web3,
    strategyRegistryCompiled.abi,
    strategyRegistryCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    strategyRegistryInitParams,
    proxyAdmin,
    deploymentConfig,
  )

  // deploy Creditlines
  const creditLinesInitParams = [admin]
  const creditLines = await utils.deployWithProxy(
    web3,
    creditLinesCompiled.abi,
    creditLinesCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    creditLinesInitParams,
    proxyAdmin,
    deploymentConfig,
  )

  // deploy savingsAccount
  const savingsAccountInitParams = [
    admin,
    strategyRegistry.options.address,
    creditLines.options.address,
  ]
  const savingsAccount = await utils.deployWithProxy(
    web3,
    savingsAccountCompiled.abi,
    savingsAccountCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    savingsAccountInitParams,
    proxyAdmin,
    deploymentConfig,
  )

  // deploy strategies
  const aaveYieldInitParams = [
    admin,
    savingsAccount.options.address,
    config.strategies.aave.wethGateway,
    config.strategies.aave.protocolDataProvider,
    config.strategies.aave.lendingPoolAddressesProvider,
  ]
  const aaveYield = await utils.deployWithProxy(
    web3,
    aaveYieldCompiled.abi,
    aaveYieldCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    aaveYieldInitParams,
    proxyAdmin,
    deploymentConfig,
  )
  const compoundYieldInitParams = [admin, savingsAccount.options.address]
  const compoundYield = await utils.deployWithProxy(
    web3,
    compoundYieldCompiled.abi,
    compoundYieldCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    compoundYieldInitParams,
    proxyAdmin,
    deploymentConfig,
  )
  const yearnYieldInitParams = [admin, savingsAccount.options.address]
  const yearnYield = await utils.deployWithProxy(
    web3,
    yearnYieldCompiled.abi,
    yearnYieldCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    yearnYieldInitParams,
    proxyAdmin,
    deploymentConfig,
  )

  // add deployed strategies to registry
  await strategyRegistry.methods
    .addStrategy(aaveYield.options.address)
    .send(adminDeploymentConfig)
    .then(console.log)
  await strategyRegistry.methods
    .addStrategy(compoundYield.options.address)
    .send(adminDeploymentConfig)
    .then(console.log)
  await strategyRegistry.methods
    .addStrategy(yearnYield.options.address)
    .send(adminDeploymentConfig)
    .then(console.log)

  // deploy priceOracle - update it first
  const priceOracleInitParams = [admin]
  const priceOracle = await utils.deployWithProxy(
    web3,
    priceOracleCompiled.abi,
    priceOracleCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    priceOracleInitParams,
    proxyAdmin,
    deploymentConfig,
  )
  // TODO add price oracles

  // deploy verification
  const verificationInitParams = [config.actors.verifier]
  const verification = await utils.deployWithProxy(
    web3,
    verificationCompiled.abi,
    verificationCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    verificationInitParams,
    proxyAdmin,
    deploymentConfig,
  )

  // deploy poolFactory
  const poolFactory = await utils.deployWithProxy(
    web3,
    poolFactoryCompiled.abi,
    poolFactoryCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    null,
    proxyAdmin,
    deploymentConfig,
  )

  // deploy Repayments
  const repaymentsInitParams = [
    admin,
    poolFactory.options.address,
    config.repayments.votingPassRatio,
  ]
  const repayments = await utils.deployWithProxy(
    web3,
    repaymentsCompiled.abi,
    repaymentsCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    repaymentsInitParams,
    proxyAdmin,
    deploymentConfig,
  )

  // deploy Extension
  const extensionInitParams = [poolFactory.options.address]
  const extension = await utils.deployWithProxy(
    web3,
    extensionCompiled.abi,
    extensionCompiled.bytecode,
    proxyCompiled.abi,
    proxyCompiled.bytecode,
    extensionInitParams,
    proxyAdmin,
    deploymentConfig,
  )

  const token = await utils.deployContract(
    web3,
    tokenCompiled.abi,
    tokenCompiled.bytecode,
    ['USDT Token', 'USDT', '10000'], //1M USDT
    deploymentConfig,
  )

  const pool = await utils.deployContract(
    web3,
    poolCompiled.abi,
    poolCompiled.bytecode,
    [],
    deploymentConfig,
  )

  // initialize PoolFactory
  const poolFactoryInitParams = [
    pool,
    verification.options.address,
    strategyRegistry.options.address,
    admin,
    config.pool.collectionPeriod,
    config.pool.matchCollateralRatioInterval,
    config.pool.marginCallDuration,
    config.pool.collateralVolatilityThreshold,
    config.pool.gracePeriodPenaltyFraction,
    web3.eth.abi.encodeFunctionSignature(
      utils.getInitializeABI(poolCompiled.abi),
    ),
    config.pool.liquidatorRewardFraction,
    repayments.options.address,
    priceOracle.options.address,
    savingsAccount.options.address,
    extension.options.address,
  ]
  await poolFactory.methods.initialize
    .apply(null, poolFactoryInitParams)
    .send(deploymentConfig)

  const addresses = {
    strategyRegistry: strategyRegistry.options.address,
    savingsAccount: savingsAccount.options.address,
    aaveYield: aaveYield.options.address,
    compoundYield: compoundYield.options.address,
    yearnYield: yearnYield.options.address,
    priceOracle: priceOracle.options.address,
    verification: verification.options.address,
    poolFactory: poolFactory.options.address,
    repayments: repayments.options.address,
    extension: extension.options.address,
    pool: pool,
    creditLines: creditLines.options.address,
    token: token,
  }
  console.table(addresses)

  const data = JSON.stringify(addresses)

  // write JSON string to a file
  fs.writeFile('./config/address.json', data, (err) => {
    if (err) {
      throw err
    }
    console.log('JSON data is saved.')
  })
}

const deployToken = async (web3, deploymentConfig) => {
  const token = await utils.deployContract(
    web3,
    tokenCompiled.abi,
    tokenCompiled.bytecode,
    ['USDT Token', 'USDT', '10000000000000000000'], //1M USDT
    deploymentConfig,
  )
  console.log(token, '0000000000000000')
  return token
}



deploy()
