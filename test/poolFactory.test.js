const { ethers } = require('hardhat')
const chai = require('chai')
const { solidity } = require('ethereum-waffle')

chai.use(solidity)
const { expect } = chai

const Deploy = require("./deploy.helper")

let config = require('../config/config.json')
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

        this.deploy = new Deploy(this.admin, this.deployer, this.verifier);
        const contracts = await this.deploy.init()
        this.poolFactory = await contracts['poolFactory'].connect(this.admin)
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

    describe('updatepoolInitFuncSelector', async () => {
        let functionId = '0x12345678'
        it('should revert if not called by owner', async () => {
            await expect(
                this.poolFactory
                    .connect(this.address2)
                    .updatepoolInitFuncSelector(functionId),
            ).to.be.revertedWith(
                'VM Exception while processing transaction: revert Ownable: caller is not the owner',
            )
        })

        it('should updatepoolInitFuncSelector', async () => {
            await expect(this.poolFactory.updatepoolInitFuncSelector(functionId))
                .to.emit(this.poolFactory, 'PoolInitSelectorUpdated')
                .withArgs(functionId)
        })
    })

    describe('updatePoolTokenInitFuncSelector', async () => {
        let functionId = '0x12345678'
        it('should revert if not called by owner', async () => {
            await expect(
                this.poolFactory
                    .connect(this.address2)
                    .updatePoolTokenInitFuncSelector(functionId),
            ).to.be.revertedWith(
                'VM Exception while processing transaction: revert Ownable: caller is not the owner',
            )
        })

        it('should updatePoolTokenInitFuncSelector', async () => {
            await expect(this.poolFactory.updatePoolTokenInitFuncSelector(functionId))
                .to.emit(this.poolFactory, 'PoolTokenInitFuncSelector')
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
