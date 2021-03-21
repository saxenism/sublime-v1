const { ethers } = require('hardhat')
const chai = require('chai')
const { solidity } = require('ethereum-waffle')
const deployedAddress = require('../config/address.json')

let { PoolFactory } = require('../build/contracts/PoolFactory.json')

chai.use(solidity)
const { expect } = chai

describe('Deploy', () => {
  beforeEach(async () => {
    PoolFactory = await ethers.getContractFactory('PoolFactory')
    this.poolFactory = await PoolFactory.attach(deployedAddress.poolFactory)
    console.log(await this.poolFactory.owner())
  })

  describe('should check deployed contracts', async () => {
    it('should get factory owner', async () => {
      const owner = await this.poolFactory.owner()
    })
  })
})
