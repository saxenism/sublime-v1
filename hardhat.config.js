require('@nomiclabs/hardhat-ethers')
require('@nomiclabs/hardhat-waffle')
require('@nomiclabs/hardhat-ganache')
require('@openzeppelin/hardhat-upgrades')

const config = require('./config/config.json')
const mnemonic = config['ganache']['blockchain']['mnemonic']

task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(await account.getAddress())
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      throwOnTransactionFailures: true,
      forking: {
        url: 'http://127.0.0.1:8545',
      },
      accounts: {
        count: 20,
        mnemonic,
        accountsBalance: '10000000000000000000000',
      },
      blockGasLimit: 6000000000,
    },
    ganache: {
      throwOnTransactionFailures: true,
      url: 'http://127.0.0.1:8546',
      fork: 'http://127.0.0.1:8545',
      gasLimit: 6000000000,
      defaultBalanceEther: 10,
      deterministic: true,
      mnemonic,
    },
  },
  solidity: {
    version: '0.7.0',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
}
