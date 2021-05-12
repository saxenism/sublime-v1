const { ethers, network } = require("hardhat")
const chai = require('chai')
const { solidity } = require('ethereum-waffle')

chai.use(solidity)
const { expect } = chai
const Deploy = require("../deploy.helper")

const { encodeUserData } = require('../utils/utils')
const { getPoolAddress } = require("../utils/getAddress");
const timeTravel = require('../utils/time')
let config = require('../../config/config.json')

const { getCreate2Address, getContractAddress } = require('@ethersproject/address')
const { parseEther } = require('@ethersproject/units')

const poolCompiled = require('../../build/contracts/Pool.json')
const poolTokenCompiled = require('../../build/contracts/PoolToken.json')

const deploymentNetwork = 'ganache'

config = config[deploymentNetwork];

describe('Deploy pool', () => {
    before(async () => {
        const accounts = await ethers.getSigners();
        [
            this.proxyAdmin,
            this.admin,
            this.deployer,
            this.verifier,
            this.borrower,
            this.lender,
            this.address1,
            this.address2,
        ] = accounts;
    
        this.deploy = new Deploy(this.admin, this.deployer, this.verifier);
        const contracts = await this.deploy.init()
        this.contracts = contracts;
        this.poolFactory = await contracts['poolFactory'].connect(this.admin)
        this.token = await contracts['token'].connect(this.admin)
        this.token1 = await contracts['token1'].connect(this.admin)
    
        await this.deploy.verifyBorrower(
            this.borrower.address,
            encodeUserData('borrower'),
        )
    })

    it('pool requesting ERC20 with Ether as collateral', async () => {
        const salt = encodeUserData(config.OpenBorrowPool.salt+parseInt(Math.random*1000))
        const newPool = getPoolAddress(deploymentNetwork, this.borrower.address, this.token.address, ethers.constants.AddressZero, ethers.constants.AddressZero, this.poolFactory.address, salt, this.contracts['pool'].address);
        const nonce = (await this.poolFactory.provider.getTransactionCount(this.poolFactory.address))+1;
        const newPoolTokenAddress = getContractAddress({
            from: this.poolFactory.address,
            nonce
        })

        const poolCreateTx = this.poolFactory
            .connect(this.borrower)
            .createPool(
                config.OpenBorrowPool.poolSize,
                config.OpenBorrowPool.minBorrowAmountFraction,
                this.token.address,
                ethers.constants.AddressZero,
                config.OpenBorrowPool.collateralRatio,
                config.OpenBorrowPool.borrowRate,
                config.OpenBorrowPool.repaymentInterval,
                config.OpenBorrowPool.noOfRepaymentIntervals,
                ethers.constants.AddressZero,
                config.OpenBorrowPool.collateralAmount,
                false,
                salt,
                { value: config.OpenBorrowPool.collateralAmount },
            );

        await expect(poolCreateTx)
            .to.emit(this.poolFactory, 'PoolCreated')
            .withArgs(newPool, this.borrower.address, newPoolTokenAddress)

        expect(await this.poolFactory.openBorrowPoolRegistry(newPool)).to.be
            .true
    })

    it('pool requesting Ether with ERC20 as collateral', async () => {
        const salt = encodeUserData(config.OpenBorrowPool.salt+parseInt(Math.random*1000))

        const newPool = getPoolAddress(deploymentNetwork, this.borrower.address, ethers.constants.AddressZero, this.token.address, ethers.constants.AddressZero, this.poolFactory.address, salt, this.contracts['pool'].address);
        const nonce = (await this.poolFactory.provider.getTransactionCount(this.poolFactory.address))+1;
        const newPoolTokenAddress = getContractAddress({
            from: this.poolFactory.address,
            nonce
        })
        
        await this.token.transfer(this.borrower.address, config.OpenBorrowPool.collateralAmount);
        await this.token.connect(this.borrower).approve(newPool, config.OpenBorrowPool.collateralAmount)

        const poolCreateTx = this.poolFactory
            .connect(this.borrower)
            .createPool(
                config.OpenBorrowPool.poolSize,
                config.OpenBorrowPool.minBorrowAmountFraction,
                ethers.constants.AddressZero,
                this.token.address,
                config.OpenBorrowPool.collateralRatio,
                config.OpenBorrowPool.borrowRate,
                config.OpenBorrowPool.repaymentInterval,
                config.OpenBorrowPool.noOfRepaymentIntervals,
                ethers.constants.AddressZero,
                config.OpenBorrowPool.collateralAmount,
                false,
                salt,
                { value: config.OpenBorrowPool.collateralAmount },
            );
        // const tx = await poolCreateTx;
        // console.log((await tx.wait()).events[0].args.bytecode)
        await expect(poolCreateTx)
            .to.emit(this.poolFactory, 'PoolCreated')
            .withArgs(newPool, this.borrower.address, newPoolTokenAddress)

        expect(await this.poolFactory.openBorrowPoolRegistry(newPool)).to.be
            .true
    })

    it('pool requesting ERC20 with ERC20 as collateral', async () => {
        const salt = encodeUserData(config.OpenBorrowPool.salt+parseInt(Math.random*1000))

        const newPool = getPoolAddress(deploymentNetwork, this.borrower.address, this.token.address, this.token1.address, ethers.constants.AddressZero, this.poolFactory.address, salt, this.contracts['pool'].address);
        const nonce = (await this.poolFactory.provider.getTransactionCount(this.poolFactory.address))+1;
        const newPoolTokenAddress = getContractAddress({
            from: this.poolFactory.address,
            nonce
        })
        
        await this.token1.transfer(this.borrower.address, config.OpenBorrowPool.collateralAmount);
        await this.token1.connect(this.borrower).approve(newPool, config.OpenBorrowPool.collateralAmount)

        const poolCreateTx = this.poolFactory
            .connect(this.borrower)
            .createPool(
                config.OpenBorrowPool.poolSize,
                config.OpenBorrowPool.minBorrowAmountFraction,
                this.token.address,
                this.token1.address,
                config.OpenBorrowPool.collateralRatio,
                config.OpenBorrowPool.borrowRate,
                config.OpenBorrowPool.repaymentInterval,
                config.OpenBorrowPool.noOfRepaymentIntervals,
                ethers.constants.AddressZero,
                config.OpenBorrowPool.collateralAmount,
                false,
                salt,
                { value: config.OpenBorrowPool.collateralAmount },
            );
        // const tx = await poolCreateTx;
        // console.log((await tx.wait()).events[0].args.bytecode)
        await expect(poolCreateTx)
            .to.emit(this.poolFactory, 'PoolCreated')
            .withArgs(newPool, this.borrower.address, newPoolTokenAddress)

        expect(await this.poolFactory.openBorrowPoolRegistry(newPool)).to.be
            .true
    })

    it('pool requesting ERC20 with Ether as collateral from savings account', async () => {
        const salt = encodeUserData(config.OpenBorrowPool.salt+parseInt(Math.random*1000))
        const newPool = getPoolAddress(deploymentNetwork, this.borrower.address, this.token.address, ethers.constants.AddressZero, this.contracts.yearnYield.address, this.poolFactory.address, salt, this.contracts['pool'].address);
        const nonce = (await this.poolFactory.provider.getTransactionCount(this.poolFactory.address))+1;
        const newPoolTokenAddress = getContractAddress({
            from: this.poolFactory.address,
            nonce
        })
        

        const poolCreateTx = this.poolFactory
            .connect(this.borrower)
            .createPool(
                config.OpenBorrowPool.poolSize,
                config.OpenBorrowPool.minBorrowAmountFraction,
                this.token.address,
                ethers.constants.AddressZero,
                config.OpenBorrowPool.collateralRatio,
                config.OpenBorrowPool.borrowRate,
                config.OpenBorrowPool.repaymentInterval,
                config.OpenBorrowPool.noOfRepaymentIntervals,
                this.contracts.yearnYield.address,
                config.OpenBorrowPool.collateralAmount,
                true,
                salt,
                { value: config.OpenBorrowPool.collateralAmount },
            );

        await expect(poolCreateTx)
            .to.emit(this.poolFactory, 'PoolCreated')
            .withArgs(newPool, this.borrower.address, newPoolTokenAddress)

        expect(await this.poolFactory.openBorrowPoolRegistry(newPool)).to.be
            .true
    })

    it('pool requesting Ether with ERC20 as collateral from savings account', () => {

    })

    it('pool with no savings strategy requesting Ether with ERC20 as collateral', () => {

    })

    it('pool with no savings strategy requesting ERC20 with Ether as collateral', () => {

    })

    describe('check limits on inputs', () => {
        it('')
    })
})