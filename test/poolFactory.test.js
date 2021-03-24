const { ethers } = require('hardhat')
const chai = require('chai')
const { solidity } = require('ethereum-waffle')

chai.use(solidity)
const { expect } = chai
const poolFactoryCompiled = require('../build/contracts/PoolFactory.json')
const verificationCompiled = require('../build/contracts/Verification.json')
const strategyRegistryCompiled = require('../build/contracts/StrategyRegistry.json')
const priceOracleCompiled = require('../build/contracts/PriceOracle.json')

const deployedAddress = require('../config/address.json')
const { encodeUserData } = require('./utils/utils')
let config = require('../config/config.json')
const { getContractAddress } = require('@ethersproject/address')
config = config['ganache']

describe('PoolFactory', () => {
  before(async () => {
    ;[
      this.deployer,
      this.admin,
      this.proxyAdmin,
      this.verifier,
      this.borrower,
      this.address1,
      this.address2,
    ] = await ethers.getSigners()

    this.poolFactory = new ethers.Contract(
      deployedAddress.poolFactory,
      poolFactoryCompiled.abi,
      this.admin,
    )
  })

  describe('createPool', async () => {
    before(async () => {
      //verification
      this.verification = new ethers.Contract(
        deployedAddress.verification,
        verificationCompiled.abi,
        this.verifier,
      )

      await this.verification.registerUser(
        this.borrower.address,
        encodeUserData(ethers, 'borrower'),
      )

      //add price feed
      this.priceOracle = new ethers.Contract(
        deployedAddress.priceOracle,
        priceOracleCompiled.abi,
        this.admin,
      )
      await this.priceOracle.setfeedAddress(
        deployedAddress.token,
        ethers.constants.AddressZero,
        deployedAddress.oracle,
        deployedAddress.oracle,
      )

      //add yield to verified strategy
      this.strategyRegistry = new ethers.Contract(
        deployedAddress.strategyRegistry,
        strategyRegistryCompiled.abi,
        this.admin,
      )

      //add yield
      await this.strategyRegistry.addStrategy(ethers.constants.AddressZero)

      // register borrow and collateral tokens to Sublime
      await this.poolFactory.updateSupportedBorrowTokens(
        deployedAddress.token,
        true,
      )

      await this.poolFactory.updateSupportedCollateralTokens(
        ethers.constants.AddressZero,
        true,
      )
    })

    it('should create pool', async () => {
      this.pool = await getContractAddress({
        from: this.poolFactory.address,
        nonce: 1,
      })

      await expect(
        this.poolFactory
          .connect(this.borrower)
          .createPool(
            config.OpenBorrowPool.poolSize,
            config.OpenBorrowPool.minBorrowAmountFraction,
            deployedAddress.token,
            ethers.constants.AddressZero,
            config.OpenBorrowPool.collateralRatio,
            config.OpenBorrowPool.borrowRate,
            config.OpenBorrowPool.repaymentInterval,
            config.OpenBorrowPool.noOfRepaymentIntervals,
            ethers.constants.AddressZero,
            config.OpenBorrowPool.collateralAmount,
            config.OpenBorrowPool.transferFromSavingsAccount,
            { value: config.OpenBorrowPool.collateralAmount },
          ),
      )
        .to.emit(this.poolFactory, 'PoolCreated')
        .withArgs(this.pool, this.borrower.address)
    })

    it('should revert if not deployed by borrower', async () => {
      //verification
      this.verification = new ethers.Contract(
        deployedAddress.verification,
        verificationCompiled.abi,
        this.verifier,
      )

      await this.verification.unregisterUser(this.borrower.address)

      await expect(
        this.poolFactory.createPool(
          config.OpenBorrowPool.poolSize,
          config.OpenBorrowPool.minBorrowAmountFraction,
          deployedAddress.token,
          ethers.constants.AddressZero,
          config.OpenBorrowPool.collateralRatio,
          config.OpenBorrowPool.borrowRate,
          config.OpenBorrowPool.repaymentInterval,
          config.OpenBorrowPool.noOfRepaymentIntervals,
          ethers.constants.AddressZero,
          config.OpenBorrowPool.collateralAmount,
          config.OpenBorrowPool.transferFromSavingsAccount,
        ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert PoolFactory::onlyBorrower - Only a valid Borrower can create Pool',
      )
    })
  })

  //will be tested with pool
  describe('destroyPool', async () => {
    it('should revert if not called by registered pool', async () => {
      await expect(
        this.poolFactory.connect(this.address2).destroyPool(),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert PoolFactory::onlyPool - Only pool can destroy itself',
      )
    })

    // it('should destroyPool and remove pool from registry', async () => {
    //   await this.poolFactory.openBorrowPoolRegistry
    //     .withArgs(this.pool)
    //     .returns(true)

    //   await this.poolFactory.connect(this.pool).destroyPool()

    //   await this.poolFactory.openBorrowPoolRegistry
    //     .withArgs(this.pool)
    //     .returns(false)
    // })
  })

  describe('updateSupportedBorrowTokens', async () => {
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateSupportedBorrowTokens(this.address1.address, true),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateSupportedBorrowTokens', async () => {
      await expect(
        this.poolFactory.updateSupportedBorrowTokens(
          this.address1.address,
          true,
        ),
      )
        .to.emit(this.poolFactory, 'BorrowTokenUpdated')
        .withArgs(this.address1.address, true)
    })
  })

  describe('updateSupportedCollateralTokens', async () => {
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateSupportedCollateralTokens(this.address1.address, true),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateSupportedCollateralTokens', async () => {
      await expect(
        this.poolFactory.updateSupportedCollateralTokens(
          this.address1.address,
          true,
        ),
      )
        .to.emit(this.poolFactory, 'CollateralTokenUpdated')
        .withArgs(this.address1.address, true)
    })
  })

  describe('updateInitializeFunctionId', async () => {
    let functionId = '0x12345678'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateInitializeFunctionId(functionId),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateInitializeFunctionId', async () => {
      await expect(this.poolFactory.updateInitializeFunctionId(functionId))
        .to.emit(this.poolFactory, 'InitializeFunctionUpdated')
        .withArgs(functionId)
    })
  })

  describe('updatePoolLogic', async () => {
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updatePoolLogic(this.address1.address),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updatePoolLogic', async () => {
      await expect(this.poolFactory.updatePoolLogic(this.address1.address))
        .to.emit(this.poolFactory, 'PoolLogicUpdated')
        .withArgs(this.address1.address)
    })
  })

  describe('updateUserRegistry', async () => {
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateUserRegistry(this.address1.address),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateUserRegistry', async () => {
      await expect(this.poolFactory.updateUserRegistry(this.address1.address))
        .to.emit(this.poolFactory, 'UserRegistryUpdated')
        .withArgs(this.address1.address)
    })
  })

  describe('updateStrategyRegistry', async () => {
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateStrategyRegistry(this.address1.address),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateStrategyRegistry', async () => {
      await expect(
        this.poolFactory.updateStrategyRegistry(this.address1.address),
      )
        .to.emit(this.poolFactory, 'StrategyRegistryUpdated')
        .withArgs(this.address1.address)
    })
  })

  describe('updateRepaymentImpl', async () => {
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateRepaymentImpl(this.address1.address),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateRepaymentImpl', async () => {
      await expect(this.poolFactory.updateRepaymentImpl(this.address1.address))
        .to.emit(this.poolFactory, 'RepaymentImplUpdated')
        .withArgs(this.address1.address)
    })
  })

  describe('updatePriceoracle', async () => {
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updatePriceoracle(this.address1.address),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updatePriceoracle', async () => {
      await expect(this.poolFactory.updatePriceoracle(this.address1.address))
        .to.emit(this.poolFactory, 'PriceOracleUpdated')
        .withArgs(this.address1.address)
    })
  })

  describe('updateCollectionPeriod', async () => {
    let collectionPeriod = '86400'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateCollectionPeriod(collectionPeriod),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateCollectionPeriod', async () => {
      await expect(this.poolFactory.updateCollectionPeriod(collectionPeriod))
        .to.emit(this.poolFactory, 'CollectionPeriodUpdated')
        .withArgs(collectionPeriod)
    })
  })

  describe('updateMatchCollateralRatioInterval', async () => {
    let matchCollateralRatioInterval = '86400'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateMatchCollateralRatioInterval(matchCollateralRatioInterval),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateMatchCollateralRatioInterval', async () => {
      await expect(
        this.poolFactory.updateMatchCollateralRatioInterval(
          matchCollateralRatioInterval,
        ),
      )
        .to.emit(this.poolFactory, 'MatchCollateralRatioIntervalUpdated')
        .withArgs(matchCollateralRatioInterval)
    })
  })

  describe('updateMarginCallDuration', async () => {
    let marginCallDuration = '86400'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateMarginCallDuration(marginCallDuration),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateMarginCallDuration', async () => {
      await expect(
        this.poolFactory.updateMarginCallDuration(marginCallDuration),
      )
        .to.emit(this.poolFactory, 'MarginCallDurationUpdated')
        .withArgs(marginCallDuration)
    })
  })

  describe('updateCollateralVolatilityThreshold', async () => {
    let collateralVolatilityThreshold = '10'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateCollateralVolatilityThreshold(collateralVolatilityThreshold),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateCollateralVolatilityThreshold', async () => {
      await expect(
        this.poolFactory.updateCollateralVolatilityThreshold(
          collateralVolatilityThreshold,
        ),
      )
        .to.emit(this.poolFactory, 'CollateralVolatilityThresholdUpdated')
        .withArgs(collateralVolatilityThreshold)
    })
  })

  describe('updateGracePeriodPenaltyFraction', async () => {
    let gracePeriodPenaltyFraction = '10'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateGracePeriodPenaltyFraction(gracePeriodPenaltyFraction),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateGracePeriodPenaltyFraction', async () => {
      await expect(
        this.poolFactory.updateGracePeriodPenaltyFraction(
          gracePeriodPenaltyFraction,
        ),
      )
        .to.emit(this.poolFactory, 'GracePeriodPenaltyFractionUpdated')
        .withArgs(gracePeriodPenaltyFraction)
    })
  })

  describe('updateLiquidatorRewardFraction', async () => {
    let liquidatorRewardFraction = '10'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateLiquidatorRewardFraction(liquidatorRewardFraction),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateLiquidatorRewardFraction', async () => {
      await expect(
        this.poolFactory.updateLiquidatorRewardFraction(
          liquidatorRewardFraction,
        ),
      )
        .to.emit(this.poolFactory, 'LiquidatorRewardFractionUpdated')
        .withArgs(liquidatorRewardFraction)
    })
  })

  describe('updatePoolSizeLimit', async () => {
    let min = '1000'
    let max = '10000'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory.connect(this.address2).updatePoolSizeLimit(min, max),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updatePoolSizeLimit', async () => {
      await expect(this.poolFactory.updatePoolSizeLimit(min, max))
        .to.emit(this.poolFactory, 'LimitsUpdated')
        .withArgs('PoolSize', min, max)
    })
  })

  describe('updateCollateralRatioLimit', async () => {
    let min = '4000'
    let max = '10000'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateCollateralRatioLimit(min, max),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateCollateralRatioLimit', async () => {
      await expect(this.poolFactory.updateCollateralRatioLimit(min, max))
        .to.emit(this.poolFactory, 'LimitsUpdated')
        .withArgs('CollateralRatio', min, max)
    })
  })

  describe('updateBorrowRateLimit', async () => {
    let min = '1000'
    let max = '10000'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory.connect(this.address2).updateBorrowRateLimit(min, max),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateBorrowRateLimit', async () => {
      await expect(this.poolFactory.updateBorrowRateLimit(min, max))
        .to.emit(this.poolFactory, 'LimitsUpdated')
        .withArgs('BorrowRate', min, max)
    })
  })

  describe('updateRepaymentIntervalLimit', async () => {
    let min = '100000'
    let max = '1000000'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateRepaymentIntervalLimit(min, max),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateRepaymentIntervalLimit', async () => {
      await expect(this.poolFactory.updateRepaymentIntervalLimit(min, max))
        .to.emit(this.poolFactory, 'LimitsUpdated')
        .withArgs('RepaymentInterval', min, max)
    })
  })

  describe('updateNoOfRepaymentIntervalsLimit', async () => {
    let min = '1'
    let max = '20'
    it('should revert if not called by owner', async () => {
      await expect(
        this.poolFactory
          .connect(this.address2)
          .updateNoOfRepaymentIntervalsLimit(min, max),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should updateNoOfRepaymentIntervalsLimit', async () => {
      await expect(this.poolFactory.updateNoOfRepaymentIntervalsLimit(min, max))
        .to.emit(this.poolFactory, 'LimitsUpdated')
        .withArgs('NoOfRepaymentIntervals', min, max)
    })
  })
})
