const { ethers, network } = require('hardhat')
const chai = require('chai')
const { solidity } = require('ethereum-waffle')

chai.use(solidity)
const { expect } = chai
const Deploy = require("./deploy.helper")

const { encodeUserData } = require('./utils/utils')
const timeTravel = require('./utils/time')
let config = require('../config/config.json')

const { getCreate2Address } = require('@ethersproject/address')
const { parseEther } = require('@ethersproject/units')
config = config['ganache']

const poolCompiled = require('../build/contracts/Pool/Pool.sol/Pool.json')
const poolTokenCompiled = require('../build/contracts/Pool/PoolToken.sol/PoolToken.json')

describe('PoolToken', () => {
  before(async () => {
    const accounts = await ethers.getSigners()
      ;[
        this.proxyAdmin,
        this.admin,
        this.deployer,
        this.verifier,
        this.borrower,
        this.lender,
        this.address1,
        this.address2,
      ] = accounts

    this.deploy = new Deploy(this.admin, this.deployer, this.verifier);
    const contracts = await this.deploy.init()
    this.poolFactory = await contracts['poolFactory'].connect(this.admin)
    this.borrowToken = await contracts['token'].connect(this.admin)

    await this.deploy.verifyBorrower(
      this.borrower.address,
      encodeUserData('borrower'),
    )

    const data = await this.deploy.deployPool(
      this.poolFactory,
      this.borrower,
      this.borrowToken.address,
      ethers.constants.AddressZero
    );

    this.pool = new ethers.Contract(
      data.pool,
      poolCompiled.abi,
      this.borrower,
    )

    await this.borrowToken
      .mint(this.lender.address, parseEther('10'))

    this.poolToken = await new ethers.Contract(
      data.poolToken,
      poolTokenCompiled.abi,
      this.admin,
    )
  })

  describe('lend', async () => {
    const amountLent = parseEther('0.01')
    it('should lend and mint pool tokens to lender', async () => {
      await this.borrowToken
        .connect(this.lender)
        .approve(this.pool.address, amountLent)

      await this.pool
        .connect(this.lender)
        .lend(this.lender.address, amountLent, false)

      expect(await this.poolToken.balanceOf(this.lender.address)).to.equal(
        amountLent,
      )
    })

    it('should transfer and transferFrom tokens', async () => {
      await this.poolToken.connect(this.lender).transfer(this.address1.address, parseEther('0.001'));

      expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
        parseEther('0.001'),
      )

      await this.poolToken
        .connect(this.lender)
        .approve(this.address1.address, amountLent)

      await this.poolToken
        .connect(this.address1)
        .transferFrom(this.lender.address, this.address2.address, parseEther('0.005'))

      expect(await this.poolToken.balanceOf(this.address2.address)).to.equal(
        parseEther('0.005'),
      )

    })
  })
})
