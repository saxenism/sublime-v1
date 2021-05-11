const { ethers, network } = require("hardhat")
const chai = require('chai')
const { solidity } = require('ethereum-waffle')

chai.use(solidity)
const { expect } = chai
const Deploy = require("./deploy.helper")

const { encodeUserData } = require('./utils/utils')
const { getPoolAddress } = require("./utils/getAddress");
const timeTravel = require('./utils/time')
let config = require('../config/config.json')

const { getCreate2Address } = require('@ethersproject/address')
const { parseEther } = require('@ethersproject/units')
config = config['ganache']

const poolCompiled = require('../build/contracts/Pool/Pool.sol/Pool.json')
const poolTokenCompiled = require('../build/contracts/Pool/PoolToken.sol/PoolToken.json')
const CompoundWithdrawAccount = "0x33333333deadbeefdeadbeefdeadbeefdeadbeef";


describe.only('Pool', () => {
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
            this.accountToDeposit,this.mockCreditLineAddress
        ] = accounts;
        this.salt = encodeUserData(config.OpenBorrowPool.salt)

        this.deploy = new Deploy(this.admin, this.deployer, this.verifier);
        const contracts = await this.deploy.init()
        this.contracts = contracts;
        this.poolFactory = await contracts['poolFactory'].connect(this.admin)
        this.token = await contracts['token'].connect(this.admin)

        await this.deploy.verifyBorrower(
            this.borrower.address,
            encodeUserData('borrower'),
        )
    })
    describe('when borrowAmount is ERC20', async () => {
        before(async () => {
            const { pool, poolToken } = await this.deploy.deployPool(
                this.poolFactory,
                this.borrower,
                this.token.address,
                ethers.constants.AddressZero
            );
    
            this.pool = new ethers.Contract(
                pool,
                poolCompiled.abi,
                this.borrower,
            )
    
            await this.token
                .connect(this.admin)
                .mint(this.lender.address, parseEther('10'))
    
            this.poolToken = await new ethers.Contract(
                poolToken,
                poolTokenCompiled.abi,
                this.admin,
            )
        })
        it('ERC20 lend without overflow', async () => {
          const amountLent = parseEther('0.01')
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, amountLent)
  
          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, amountLent, false)
  
          expect(await this.poolToken.balanceOf(this.lender.address)).to.equal(
            amountLent,
          )
        })

        it('ERC20 lend with overflow', async () => {
            const amountLent = parseEther('0.04')
            await this.token
                .connect(this.admin)
                .mint(this.address1.address, parseEther('10'))

            await this.token
            .connect(this.address1)
            .approve(this.pool.address, amountLent)
    
            let iBalance = await this.token.balanceOf(this.address1.address);
            await this.pool
            .connect(this.address1)
            .lend(this.address1.address, amountLent, false)
            
            let fBalance = await this.token.balanceOf(this.address1.address);
      
            expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
                iBalance.sub(fBalance),
            )
          })
  
    })
    
    describe('when borrowAmount is Ethereum', async () => {
        before(async () => {
            const { pool, poolToken } = await this.deploy.deployPool(
                this.poolFactory,
                this.borrower,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero
            );
    
            this.pool = new ethers.Contract(
                pool,
                poolCompiled.abi,
                this.borrower,
            )
        
    
            this.poolToken = await new ethers.Contract(
                poolToken,
                poolTokenCompiled.abi,
                this.admin,
            )
        })
        it('ETC lend without overflow', async () => {
            const amountLent = parseEther('0.0001')
            const transaction = {
                value: amountLent,
            }
            await this.pool
            .connect(this.lender)
            .lend(this.lender.address, amountLent, false,transaction)
            
            expect(await this.poolToken.balanceOf(this.lender.address)).to.equal(
                amountLent,
            )
        })
        it('ETC lend with overflow', async () => {
            const amountLent = parseEther('0.2')
            const transaction = {
                value: amountLent,
            }
            let iBalance = await this.address1.getBalance();
            await this.pool
            .connect(this.address1)
            .lend(this.address1.address, amountLent, false,transaction)
            
            let fBalance = await this.address1.getBalance();
            expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
                iBalance.sub(fBalance),
            )
        })
    })
    describe('when pool tokens are transferred', async () => {
        before(async () => {
            const { pool, poolToken } = await this.deploy.deployPool(
                this.poolFactory,
                this.borrower,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero
            );
    
            this.pool = new ethers.Contract(
                pool,
                poolCompiled.abi,
                this.borrower,
            )
        
            this.poolToken = await new ethers.Contract(
                poolToken,
                poolTokenCompiled.abi,
                this.admin,
            )
            const amountLent = parseEther('0.0001')
            const transaction = {
                value: amountLent,
            }
            await this.pool
            .connect(this.lender)
            .lend(this.lender.address, amountLent, false,transaction)
            
            expect(await this.poolToken.balanceOf(this.lender.address)).to.equal(
                amountLent,
            )
        })
        it('transferring pool tokens', async () => {
            let iBalance = await this.address1.getBalance();
            await this.poolToken.connect(this.lender).transfer(this.address1.address,parseEther('0.00001') )
            let fBalance = await this.address1.getBalance();
            expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
                fBalance.sub(iBalance),
            )
        })
    })
    describe('lend using savings account', async () => {
        before(async () => {
            const { pool, poolToken } = await this.deploy.deployPool(
                this.poolFactory,
                this.borrower,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero
            );
    
            this.pool = new ethers.Contract(
                pool,
                poolCompiled.abi,
                this.borrower,
            )
        
            this.poolToken = await new ethers.Contract(
                poolToken,
                poolTokenCompiled.abi,
                this.admin,
            )
            const SavingsAccount = await ethers.getContractFactory("SavingsAccount");
            this.savingsAccount = await SavingsAccount.connect(
            this.proxyAdmin
            ).deploy();

            this.StrategyRegistry = await ethers.getContractFactory("StrategyRegistry");
            this.strategyRegistry = await this.StrategyRegistry.connect(
            this.proxyAdmin
            ).deploy();

            await this.savingsAccount.initialize(
            this.admin.address,
            this.strategyRegistry.address,
            this.mockCreditLineAddress.address
            );

            const depositValueToTest = parseEther('1');
            await this.savingsAccount
            .connect(this.lender)
            .depositTo(
              depositValueToTest,
              ethers.constants.AddressZero,
              ethers.constants.AddressZero,
              this.lender.address,
              { value: depositValueToTest }
            );
            await this.savingsAccount
            .connect(this.lender)
            .approve(
                ethers.constants.AddressZero,
                this.pool.address,
                parseEther('0.001')
            );
            
        })
        it('should lend using Saving Account', async () => {
            
            // let iBalance = await this.address1.getBalance();
            const amountLent = parseEther('0.0001')
            let initialBalance = await this.savingsAccount.userLockedBalance(
                this.lender.address,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero
              );
            await this.pool
            .connect(this.lender)
            .lend(this.lender.address, amountLent, true)
            let finalBalance = await this.savingsAccount.userLockedBalance(
                this.lender.address,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero
              );
            expect(initialBalance.sub(finalBalance)).equal(amountLent);
          
        })
    })
})