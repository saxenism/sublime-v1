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

function getSalt(ethers, address, salt) {
  const encodedData = ethers.utils.defaultAbiCoder.encode(
    ['bytes32', 'address'],
    [salt, address],
  )
  return ethers.utils.keccak256(encodedData)
}

function getInitCodehash(ethers, proxyBytecode, poolImplAddr, poolData, admin) {
  const initialize = ethers.utils.defaultAbiCoder.encode(['address', 'address', 'bytes'], [poolImplAddr, admin, poolData]);
  const encodedData = ethers.utils.defaultAbiCoder.encode(['bytes', 'bytes'], [proxyBytecode, initialize])
  return ethers.utils.keccak256(encodedData)
}

module.exports = { generateAddress, encodeUserData, getSalt, getInitCodehash }
