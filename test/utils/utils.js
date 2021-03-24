const ethJsUtil = require('ethereumjs-util')
const Web3 = require('web3')
let web3 = new Web3('http://127.0.0.1:8546')

async function generateAddress(address, toAdd = 0) {
  let transactionCount = await getTransactionCount(address)
  //toAdd - to increase tx count for generating future addresses
  transactionCount += toAdd

  const futureAddress = ethJsUtil.bufferToHex(
    ethJsUtil.generateAddress(address, transactionCount),
  )
  return futureAddress
}

async function getTransactionCount(address) {
  const transactionCount = await web3.eth.getTransactionCount(address)
  return transactionCount
}

function encodeUserData(ethers, data) {
  return ethers.utils.formatBytes32String(data)
}

module.exports = { generateAddress, encodeUserData }
