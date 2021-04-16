const Web3 = require('web3')
const allConfigs = require('../config/config.json')
const keystore = require('../keystore/keystore.json')

const creditLinesCompiled = require('../build/contracts/CreditLine.json')
const config = allConfigs[allConfigs.network]

let web3 = new Web3(config.blockchain.url)
const utils = require('./utils')

const admin = config.actors.admin
const lender = config.actors.lender
const borrower = config.actors.borrower

const adminTransactionConfig = {
  from: admin,
  gas: config.tx.gas,
  gasPrice: config.tx.gasPrice,
}

const lenderTransactionConfig = {
  from: lender,
  gas: config.tx.gas,
  gasPrice: config.tx.gasPrice,
}

const borrowerTransactionConfig = {
  from: borrower,
  gas: config.tx.gas,
  gasPrice: config.tx.gasPrice,
}

const requestCreditLine = async (web3) => {
  web3 = await utils.addAccounts(web3, keystore)

  //create contract instance
  const creditLines = await new web3.eth.Contract(
    creditLinesCompiled.abi,
    config.deployedAddress.creditLines,
  )

  // register borrow and collateral tokens to Sublime
  await creditLines.methods
    .requestCreditLineToLender(
      lender,
      config.creditLines.borrowLimit,
      config.creditLines.liquidationThreshold,
      config.creditLines.borrowRate,
      config.creditLines.autoLiquidation,
      config.creditLines.collateralRatio,
      config.creditLines.borrowAsset,
      config.creditLines.collateralAsset,
    )
    .send(lenderTransactionConfig)
    .then(console.log)

  console.log('Credit line requested')
}

requestCreditLine(web3)
