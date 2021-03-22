const { ethers } = require('hardhat')
const { expect } = require('chai')
const allConfigs = require('../config/address.json')

const strategyRegistryCompiled = require('../build/contracts/StrategyRegistry.json')
const aaveYieldCompiled = require("../build/contracts/AaveYield.json");
const compoundYieldCompiled = require("../build/contracts/CompoundYield.json");
const yearnYieldCompiled = require("../build/contracts/YearnYield.json");
const savingsAccountCompiled = require("../build/contracts/SavingsAccount.json");
const priceOracleCompiled = require("../build/contracts/PriceOracle.json");
const verificationCompiled = require("../build/contracts/Verification.json");
const repaymentsCompiled = require("../build/contracts/Repayments.json");
const extensionCompiled = require("../build/contracts/Extension.json");
const poolFactoryCompiled = require("../build/contracts/PoolFactory.json");
const creditLinesCompiled = require("../build/contracts/CreditLine.json");
const poolCompiled = require("../build/contracts/Pool.json");

describe('Deploy', () => {
  before(async () => {
    [this.deployer, this.admin, this.proxyAdmin] = await ethers.getSigners()

    this.strategyRegistry = new ethers.Contract(
      allConfigs.strategyRegistry,
      strategyRegistryCompiled.abi,
      this.admin,
    )
  })

  describe('should check deployed contracts', async () => {
    it('should get factory owner', async () => {
      const owner = await this.strategyRegistry.owner()
      expect(owner).to.equal(this.admin.address)

      console.log(await this.strategyRegistry.maxStrategies())

      await this.strategyRegistry.addStrategy(this.deployer.address)

      const strategy = await this.strategyRegistry.strategies(3)
      expect(strategy).to.equal(this.deployer.address)
    })
  })
})
