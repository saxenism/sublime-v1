require('@nomiclabs/hardhat-ethers')
require('@nomiclabs/hardhat-waffle')
require('@nomiclabs/hardhat-ganache')
require('@openzeppelin/hardhat-upgrades')
require("solidity-coverage");

const config = require("./config/config.json");
const mnemonic = config["ganache"]["blockchain"]["mnemonic"];

task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(await account.getAddress())
  }
})

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    ganache: {
      url: "http://127.0.0.1:8545",
      gasLimit: 6000000000,
      defaultBalanceEther: 100,
      deterministic: true,
      mnemonic,
      throwOnTransactionFailures: true,
      fork: 'http://127.0.0.1:8545',
    },
    hardhat: {
      forking: {
        url:
          "https://eth-mainnet.alchemyapi.io/v2/snGskhAXMQaRLnJaxbcfOL7U5_bSZl_Y",
        blockNumber: 12000000,
      },
      gasLimit: 12000000,
      gasPrice: 0,
      accounts: {
        count: 20,
        mnemonic,
        accountsBalance: '10000000000000000000000',
      },
      throwOnTransactionFailures: true,
    },
  },
  solidity: {
    version: "0.7.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  gasReporter: {
    enabled: true,
  },
  mocha: {
    timeout: 20000000,
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
}
