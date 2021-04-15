const { ethers } = require('hardhat')
const chai = require('chai')
const { solidity } = require('ethereum-waffle')

chai.use(solidity)
const { expect } = chai
const Deploy = require("./deploy.helper")

const { encodeUserData } = require('./utils/utils')
let config = require('../config/config.json')

const { getCreate2Address } = require('@ethersproject/address')
const { parseEther } = require('@ethersproject/units')
config = config['ganache']

const poolCompiled = require('../build/contracts/Pool.json')
const poolTokenCompiled = require('../build/contracts/PoolToken.json')

describe('Pool', () => {
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
        this.token = await contracts['token'].connect(this.admin)

        await this.deploy.verifyBorrower(
            this.borrower.address,
            encodeUserData('borrower'),
        )
    })

    describe('createPool', async () => {
        it('should create pool', async () => {

            const salt = encodeUserData('Borrower')

            //TODO: correct create2 address prediction
            this.newPool = '0xF8061dA1715f0cfFD7A61b0615e66D8754355848'
            const newPoolTokenAddress = '0xCBA0851DcDd6218eaDAAB8fD6ea91626F64D0535'

            await expect(
                this.poolFactory
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
                        config.OpenBorrowPool.transferFromSavingsAccount,
                        encodeUserData('Borrower'),
                        { value: config.OpenBorrowPool.collateralAmount },
                    ),
            )
                .to.emit(this.poolFactory, 'PoolCreated')
                .withArgs(this.newPool, this.borrower.address, newPoolTokenAddress)

            expect(await this.poolFactory.openBorrowPoolRegistry(this.newPool)).to.be
                .true
        })

        it('should revert if not deployed by borrower', async () => {
            await expect(
                this.poolFactory.createPool(
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
                    config.OpenBorrowPool.transferFromSavingsAccount,
                    encodeUserData('Borrower')
                ),
            ).to.be.revertedWith(
                'VM Exception while processing transaction: revert PoolFactory::onlyBorrower - Only a valid Borrower can create Pool',
            )
        })

        it('should revert if same salt is used for pool creation', async () => {
            await expect(
                this.poolFactory
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
                        config.OpenBorrowPool.transferFromSavingsAccount,
                        encodeUserData('Borrower'),
                        { value: config.OpenBorrowPool.collateralAmount },

                    ),
            ).to.be.revertedWith(
                'VM Exception while processing transaction: revert Create2: Failed on deploy',
            )
        })
    })

    describe('Pool functions', async () => {
        before(async () => {
            this.pool = new ethers.Contract(
                this.newPool,
                poolCompiled.abi,
                this.borrower,
            )

            this.borrowToken = this.token

            await this.borrowToken
                .connect(this.admin)
                .mint(this.lender.address, parseEther('10'))

            const OPTaddress = await this.pool.poolToken()
            this.poolToken = await new ethers.Contract(
                OPTaddress,
                poolTokenCompiled.abi,
                this.admin,
            )
        })

        describe('depositCollateral', async () => {
            it('should revert if amount depsited is zero', async () => {
                await expect(
                    this.pool.connect(this.borrower).depositCollateral(0, false),
                ).to.be.revertedWith(
                    'VM Exception while processing transaction: revert 7',
                )
            })

            it('should revert if msg.value is zero for ether as collateral ', async () => {
                await expect(
                    this.pool
                        .connect(this.borrower)
                        .depositCollateral(parseEther('1'), false),
                ).to.be.revertedWith(
                    'VM Exception while processing transaction: revert 8',
                )
            })

            it('should deposit collateral for borrower', async () => {
                await expect(
                    this.pool
                        .connect(this.borrower)
                        .depositCollateral(parseEther('1'), false, {
                            value: parseEther('1'),
                        }),
                )
                    .to.emit(this.pool, 'CollateralAdded')
                    .withArgs(this.borrower.address, parseEther('1'), parseEther('1'))
            })
        })

        describe('lend', async () => {
            const amountLent = parseEther('0.01')
            it('should lend tokens and mint pool tokens to lender', async () => {
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
        })

        describe('withdrawBorrowedAmount', async () => {
            it('should revert if not called by borrower', async () => {
                await expect(
                    this.pool.connect(this.admin).withdrawBorrowedAmount(),
                ).to.be.revertedWith(
                    'VM Exception while processing transaction: revert 1',
                )
            })

            it('should revert if loan withdrawal duration exceeds', async () => {
                await expect(
                    this.pool.withdrawBorrowedAmount(),
                ).to.be.revertedWith(
                    'VM Exception while processing transaction: revert 1',
                )
            })

            it('should cancel pool if total borrowed amount is less than expected', async () => {
                await expect(
                    this.pool.withdrawBorrowedAmount(),
                ).to.be.revertedWith(
                    'VM Exception while processing transaction: revert 1',
                )
            })

            it('should withdraw borrowed amount', async () => {
                await expect(
                    this.pool.withdrawBorrowedAmount(),
                )
                    .to.emit(this.pool, 'AmountBorrowed')
                    .withArgs(config.OpenBorrowPool.poolSize)
            })
        })

        describe('receive', async () => {
            it('should revert if eth not received from savings account', async () => {
                const transaction = {
                    to: this.pool.address,
                    value: parseEther('1'),
                }

                await expect(
                    this.borrower.sendTransaction(transaction),
                ).to.be.revertedWith(
                    'VM Exception while processing transaction: revert 35',
                )
            })
        })
    })
})
