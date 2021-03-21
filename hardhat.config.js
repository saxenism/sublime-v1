require('@nomiclabs/hardhat-waffle')
require("@nomiclabs/hardhat-ganache");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  localhost: {
    url: 'http://127.0.0.1:8545',
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
}
