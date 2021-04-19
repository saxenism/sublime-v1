const ethJsUtil = require('ethereumjs-util')
const { ethers } = require('ethers')
const Web3 = require('web3')
let web3 = new Web3('http://127.0.0.1:8545')

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

function encodeUserData(data) {
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

function getInitializeABI(abi) {
  let initializeABI;
  for (let i = 0; i < abi.length; i++) {
    if (abi[i].name == "initialize") {
      initializeABI = abi[i];
      break;
    }
  }
  return initializeABI;
}


function encodeSignature(abi) {
  return web3.eth.abi.encodeFunctionSignature(
    getInitializeABI(abi),
  )
}

module.exports = { generateAddress, encodeUserData, getSalt, getInitCodehash, encodeSignature }
