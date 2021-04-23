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

const poolCompiled = require('../build/contracts/Pool.json')
const poolTokenCompiled = require('../build/contracts/PoolToken.json')

describe('Pool', () => {
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

  describe('createPool', async () => {
    it('should create pool', async () => {
      const newPool = getPoolAddress('ganache', this.borrower.address, this.token.address, ethers.constants.AddressZero, ethers.constants.AddressZero, this.poolFactory.address, this.salt, this.contracts['pool'].address);
      const newPoolTokenAddress = '0xcD540B9A37A6db853703b78A6efC85f2696acdDf'

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
            config.OpenBorrowPool.transferFromSavingsAccount,
            this.salt,
            { value: config.OpenBorrowPool.collateralAmount },
          );

      await expect(poolCreateTx)
        .to.emit(this.poolFactory, 'PoolCreated')
        .withArgs(newPool, this.borrower.address, newPoolTokenAddress)

      expect(await this.poolFactory.openBorrowPoolRegistry(newPool)).to.be
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
          this.salt
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
            this.salt,
            { value: config.OpenBorrowPool.collateralAmount },

          ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Create2: Failed on deploy',
      )
    })
  })

  describe('Pool functions', async () => {
    beforeEach(async () => {
      const contracts = await this.deploy.init()
      this.poolFactory = await contracts['poolFactory'].connect(this.admin)
      this.token = await contracts['token'].connect(this.admin)

      await this.deploy.verifyBorrower(
        this.borrower.address,
        encodeUserData('borrower'),
      )
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
        await this.token
          .connect(this.lender)
          .approve(this.pool.address, parseEther('1'))

        await this.pool
          .connect(this.lender)
          .lend(this.lender.address, parseEther('1'), false)

        await timeTravel(network, config.pool.collectionPeriod + 100);
        await expect(
          this.pool.withdrawBorrowedAmount(),
        )
          .to.emit(this.pool, 'AmountBorrowed')
          .withArgs(config.OpenBorrowPool.poolSize)
      })
    })

    describe('End OpenBorrowPool', async () => {
      describe('cancelOpenBorrowPool', async () => {
        it('should revert if not called by borrower', async () => {
          await expect(
            this.pool.connect(this.admin).cancelOpenBorrowPool(),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 1',
          )
        })

        it('should cancel pool', async () => {
          await this.pool.connect(this.borrower).cancelOpenBorrowPool()
        })
      })

      describe('terminateOpenBorrowPool', async () => {
        it('should revert if not called by owner', async () => {
          await expect(
            this.pool.terminateOpenBorrowPool(),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 3',
          )
        })

        it('should teminate pool', async () => {
          await this.pool.connect(this.admin).terminateOpenBorrowPool()
        })
      })

      describe('closeLoan', async () => {
        before(async () => {
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, parseEther('1'))

          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, parseEther('1'), false)

          await timeTravel(network, config.pool.collectionPeriod + 100);
          await expect(
            this.pool.withdrawBorrowedAmount(),
          )
            .to.emit(this.pool, 'AmountBorrowed')
            .withArgs(config.OpenBorrowPool.poolSize)

        })

        it('should revert if not called by borrower', async () => {
          await expect(
            this.pool.closeLoan(),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 1',
          )
        })

        it('should revert if loan status is not ACTIVE', async () => {
          await expect(
            this.pool.connect(this.borrower).closeLoan(),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 1',
          )
        })

        it('should close loan', async () => {
          await this.pool.connect(this.borrower).closeLoan()
        })

        describe('withdrawLiquidity', async () => {
          it('should revert if not called by lender', async () => {
            await expect(
              this.pool.connect(this.borrower).closeLoan(),
            ).to.be.revertedWith(
              'VM Exception while processing transaction: revert 1',
            )
          })

          it('should revert if loan status is active or collection', async () => {
            await expect(
              this.pool.connect(this.borrower).closeLoan(),
            ).to.be.revertedWith(
              'VM Exception while processing transaction: revert 1',
            )
          })

          it('should transfer borrowed amount to lender and burn pool tokens', async () => {
            await this.pool.connect(this.borrower).closeLoan()
          })
        })
      })
    })

    describe('MarginCall', async () => {
      describe('requestMarginCall', async () => {
        it('should revert if not called by lender', async () => {
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, parseEther('1'))

          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, parseEther('1'), false)

          await timeTravel(network, config.pool.collectionPeriod + 100);
          await this.pool.connect(this.borrower).withdrawBorrowedAmount();

          await expect(
            this.pool.requestMarginCall(),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 2',
          )

        })

        it('should revert if pool is not active', async () => {
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, parseEther('1'))

          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, parseEther('1'), false)

          await expect(
            this.pool.connect(this.lender).requestMarginCall(),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 4',
          )
        })

        it('should revert if already in margin call', async () => {
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, parseEther('1'))

          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, parseEther('1'), false)

          await timeTravel(network, config.pool.collectionPeriod + 100);
          await this.pool.connect(this.borrower).withdrawBorrowedAmount();

          await this.pool.connect(this.lender).requestMarginCall();
          await expect(
            this.pool.connect(this.lender).requestMarginCall(),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 1',
          )
        })

        it('should request margin call', async () => {
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, parseEther('1'))

          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, parseEther('1'), false)

          await timeTravel(network, config.pool.collectionPeriod + 100);
          await this.pool.connect(this.borrower).withdrawBorrowedAmount();
          await this.pool.connect(this.lender).requestMarginCall();
        })
      })

      describe('addCollateralInMarginCall', async () => {
        const collateral = parseEther('1')

        it('should revert if loan status is not ACTIVE', async () => {
          await expect(
            this.pool.addCollateralInMarginCall(
              this.lender.address,
              collateral,
              false,
            ),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 9',
          )
        })

        it('should revert if margin call time has ended', async () => {
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, parseEther('1'))

          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, parseEther('1'), false)

          await timeTravel(network, config.pool.collectionPeriod + 100);
          await this.pool.connect(this.borrower).withdrawBorrowedAmount();

          await this.pool.connect(this.lender).requestMarginCall();

          await expect(
            this.pool.addCollateralInMarginCall(this.lender.address, 0, false),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 11',
          )

          await timeTravel(network, 1200);

          await expect(
            this.pool.addCollateralInMarginCall(
              this.lender.address,
              collateral,
              false,
            ),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 10',
          )
        })

        it('should addCollateralInMarginCall', async () => {
          await this.token
            .connect(this.lender)
            .approve(this.pool.address, parseEther('1'))

          await this.pool
            .connect(this.lender)
            .lend(this.lender.address, parseEther('1'), false)

          await timeTravel(network, config.pool.collectionPeriod + 100);
          await this.pool.connect(this.borrower).withdrawBorrowedAmount();

          await this.pool.connect(this.lender).requestMarginCall();

          await expect(
            this.pool.addCollateralInMarginCall(this.lender.address, 0, false),
          ).to.be.revertedWith(
            'VM Exception while processing transaction: revert 11',
          )

          await timeTravel(network, 1200);

          await expect(
            this.pool.addCollateralInMarginCall(
              this.lender.address,
              collateral,
              false,
            ),
          )
            .to.emit(this.pool, 'MarginCallCollateralAdded')
            .withArgs(
              this.borrower.address,
              this.borrower.address,
              collateral,
              collateral,
            )
        })
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
