const Web3 = require('web3')
const allConfigs = require('../config/config.json')
const keystore = require('../keystore/keystore.json')
const deployedAddresses = require('../config/address.json')

const priceOracleCompiled = require('../build/contracts/PriceOracle.json')
const verificationCompiled = require('../build/contracts/Verification.json')
const poolFactoryCompiled = require('../build/contracts/PoolFactory.json')
const tokenCompiled = require('../build/contracts/Token.json')
const strategyRegistryCompiled = require('../build/contracts/StrategyRegistry.json')

const config = allConfigs[allConfigs.network]
const address = config['deployedAddress']

let web3 = new Web3(config.blockchain.url)
const utils = require('./utils')

const admin = config.actors.admin
const verifier = config.actors.verifier
const borrower = config.actors.borrower

const adminTransactionConfig = {
  from: admin,
  gas: config.tx.gas,
  gasPrice: config.tx.gasPrice,
}

const verifierTransactionConfig = {
  from: verifier,
  gas: config.tx.gas,
  gasPrice: config.tx.gasPrice,
}

//For pool creation
const borrowerTransactionConfig = {
  from: borrower,
  gas: config.tx.gas,
  gasPrice: config.tx.gasPrice,
  value: config.OpenBorrowPool.collateralAmount
}

const borrowerDetails =
  '0x0100000000000000000000000000000000000000000000000000000000000000'

const createPool = async (web3) => {
  web3 = await utils.addAccounts(web3, keystore)
  //verify borrower
  await verifyBorrower(web3, borrower)

  //add price feed
  await addPriceFeed(
    web3,
    config.OpenBorrowPool.borrowTokenType,
    config.OpenBorrowPool.collateralTokenType,
    config.oracle.usd,
    config.oracle.usd,
  )

  const poolContract = await utils.generateAddress(web3, address.poolFactory)
  // approve collateral
  if (
    config.OpenBorrowPool.collateralTokenType !=
    '0x0000000000000000000000000000000000000000'
  ) {
    await approveTokens(
      web3,
      borrowerTransactionConfig,
      poolContract,
      config.OpenBorrowPool.collateralAmount,
    )
  }

  //add yield to verified strategy
  await addStrategy(web3, config.OpenBorrowPool.investedTo)

  //create contract instance
  const poolFactory = await new web3.eth.Contract(
    poolFactoryCompiled.abi,
    address.poolFactory,
  )

  // register borrow and collateral tokens to Sublime
  await poolFactory.methods
    .updateSupportedBorrowTokens(config.OpenBorrowPool.borrowTokenType, true)
    .send(adminTransactionConfig)
    .then(console.log)

  await poolFactory.methods
    .updateSupportedCollateralTokens(
      config.OpenBorrowPool.collateralTokenType,
      true,
    )
    .send(adminTransactionConfig)
    .then(console.log)

  console.log('Tokens added')

  //create pool
  await poolFactory.methods
    .createPool(
      config.OpenBorrowPool.poolSize,
      config.OpenBorrowPool.minBorrowAmountFraction,
      config.OpenBorrowPool.borrowTokenType,
      config.OpenBorrowPool.collateralTokenType,
      config.OpenBorrowPool.collateralRatio,
      config.OpenBorrowPool.borrowRate,
      config.OpenBorrowPool.repaymentInterval,
      config.OpenBorrowPool.noOfRepaymentIntervals,
      config.OpenBorrowPool.investedTo,
      config.OpenBorrowPool.collateralAmount,
      config.OpenBorrowPool.transferFromSavingsAccount,
      web3.utils.asciiToHex(config.OpenBorrowPool.salt),
    )
    .send(borrowerTransactionConfig)
    .then(console.log)

  console.log('Pool created')
}

const verifyBorrower = async (web3, borrower) => {
  //create contract instance
  const verification = await new web3.eth.Contract(
    verificationCompiled.abi,
    address.verification,
  )

  //verify borrower
  await verification.methods
    .registerUser(borrower, borrowerDetails)
    .send(verifierTransactionConfig)
    .then(console.log)

  //check if registered
  console.log('Borrower verification done: ')
  await verification.methods.isUser(borrower).call().then(console.log)
}

const addPriceFeed = async (
  web3,
  btokenAddress,
  cTokenAddress,
  priceOracle1,
  priceOracle2,
) => {
  //create contract instance
  const priceOracle = await new web3.eth.Contract(
    priceOracleCompiled.abi,
    address.priceOracle,
  )

  //add feed
  await priceOracle.methods
    .setfeedAddress(btokenAddress, cTokenAddress, priceOracle1, priceOracle2)
    .send(adminTransactionConfig)
    .then(console.log)

  //check if feed exists
  console.log('Feed exists? : ')
  await priceOracle.methods
    .doesFeedExist(btokenAddress, cTokenAddress)
    .call()
    .then(console.log)
}

const approveTokens = async (web3, transactionConfig, to, amount) => {
  const token = await new web3.eth.Contract(tokenCompiled.abi, config.USDT)

  await token.methods
    .approve(to, amount)
    .send(transactionConfig)
    .then(console.log)
}

const addStrategy = async (web3, yieldAddress) => {
  //create contract instance
  const strategyRegistry = await new web3.eth.Contract(
    strategyRegistryCompiled.abi,
    address.strategyRegistry,
  )

  //add yield
  await strategyRegistry.methods
    .addStrategy(yieldAddress)
    .send(adminTransactionConfig)
    .then(console.log)

  //check if feed exists
  console.log('Yield exists? : ')
  await strategyRegistry.methods.registry(yieldAddress).call().then(console.log)
}

createPool(web3)
