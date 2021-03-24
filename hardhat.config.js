require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ganache");
require("@openzeppelin/hardhat-upgrades");

const config = require("./config/config.json");
const mnemonic = config["ganache"]["blockchain"]["mnemonic"];

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    ganache: {
      url: "http://127.0.0.1:8545",
      gasLimit: 12000000,
      defaultBalanceEther: 100,
      deterministic: true,
      mnemonic,
    },
    hardhat: {
      forking: {
        url:
          "https://eth-mainnet.alchemyapi.io/v2/snGskhAXMQaRLnJaxbcfOL7U5_bSZl_Y",
        blockNumber: 12000000,
      },
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
    enabled: false,
  },
};
