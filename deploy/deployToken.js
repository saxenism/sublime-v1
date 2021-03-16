const Web3 = require('web3')
const allConfigs = require('../config/config.json')
const keystore = require('../keystore/keystore.json')

const tokenCompiled = require('../build/contracts/Token.json')
const utils = require('./utils')

const config = allConfigs[allConfigs.network]

let web3 = new Web3(config.blockchain.url)

const deployer = config.actors.deployer
const deploymentConfig = {
  from: deployer,
  gas: config.tx.gas,
  gasPrice: config.tx.gasPrice,
}

const addAccounts = async (web3, keystore) => {
  for (let account in keystore) {
    await web3.eth.accounts.wallet.add(keystore[account])
  }
  return web3
}

const deploy = async (web3) => {
  const token = await utils.deployContract(
    web3,
    tokenCompiled.abi,
    tokenCompiled.bytecode,
    ['USDT Token', 'USDT', '1000000000000000000000000'], //1M USDT
    deploymentConfig,
  )

  await mintTokens(
    web3,
    token.options.address,
    config.actors.borrower,
    '1000000000000000000000', //1K USDT
  )
  const addresses = {
    token: token.options.address,
  }
  console.table(addresses)
}

const mintTokens = async (web3, tokenAddress, receiver, amount) => {
  const token = await new web3.eth.Contract(tokenCompiled.abi, tokenAddress)

  await token.methods
    .mint(receiver, amount)
    .send(deploymentConfig)
    .then(console.log)
}

addAccounts(web3, keystore).then(deploy)
