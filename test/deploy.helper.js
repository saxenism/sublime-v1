const { ethers } = require('hardhat')

const allConfigs = require('../config/config.json')
const config = allConfigs['ganache']
const { encodeSignature } = require('./utils/utils')

const poolCompiled = require('../build/contracts/Pool.json')
const poolTokenCompiled = require('../build/contracts/PoolToken.json')

class Deploy {
    constructor(admin, deployer, verifier) {
        this.admin = admin
        this.deployer = deployer
        this.verifier = verifier
    }

    async init() {
        //deploy contracts (non proxy for tests)
        this.token = await this.deploy("Token", 'USDT Token', 'USDT', '10000000000000000000000')

        this.aaveYield = await this.deploy("AaveYield")
        this.compoundYield = await this.deploy("CompoundYield")
        this.yearnYield = await this.deploy("YearnYield")
        this.strategyRegistry = await this.deploy("StrategyRegistry")
        this.savingsAccount = await this.deploy("SavingsAccount")

        this.oracle = await this.deploy("FluxAggregator")
        this.priceOracle = await this.deploy("PriceOracle")

        this.verification = await this.deploy("Verification")
        this.repayments = await this.deploy("Repayments")
        this.extension = await this.deploy("Extension")
        this.poolFactory = await this.deploy("PoolFactory")
        this.pool = await this.deploy("Pool")
        this.poolToken = await this.deploy("PoolToken")

        this.creditLine = await this.deploy("CreditLine")

        //initialize contracts
        await this.strategyRegistry.initialize(this.admin.address, config.strategies.max)
        await this.savingsAccount.initialize(
            this.admin.address,
            this.strategyRegistry.address,
            this.creditLine.address
        )
        await this.aaveYield.initialize(
            this.admin.address,
            this.savingsAccount.address,
            config.strategies.aave.wethGateway,
            config.strategies.aave.protocolDataProvider,
            config.strategies.aave.lendingPoolAddressesProvider,
        )
        await this.compoundYield.initialize(this.admin.address, this.savingsAccount.address)
        await this.yearnYield.initialize(this.admin.address, this.savingsAccount.address)

        await this.priceOracle.initialize(this.admin.address)

        await this.verification.initialize(this.verifier.address)
        await this.repayments.initialize(
            this.admin.address,
            this.poolFactory.address,
            config.repayments.votingPassRatio,
            this.savingsAccount.address,
        )
        await this.extension.initialize(this.poolFactory.address)
        await this.poolFactory.initialize(
            this.verification.address,
            this.strategyRegistry.address,
            this.admin.address,
            config.pool.collectionPeriod,
            config.pool.matchCollateralRatioInterval,
            config.pool.marginCallDuration,
            config.pool.collateralVolatilityThreshold,
            config.pool.gracePeriodPenaltyFraction,
            encodeSignature(poolCompiled.abi),
            encodeSignature(poolTokenCompiled.abi),
            config.pool.liquidatorRewardFraction,
            this.priceOracle.address,
            this.savingsAccount.address,
            this.extension.address
        )

        await this.creditLine.initialize(this.admin.address)

        //setup yields
        await this.setupYields(this.strategyRegistry, [ethers.constants.AddressZero, this.aaveYield.address, this.yearnYield.address, this.compoundYield.address])
        await this.setupPoolFactory(this.token.address, ethers.constants.AddressZero);

        //transfer token ownership to admin
        await this.token.transferOwnership(this.admin.address)

        return {
            token: this.token,
            aaveYield: this.aaveYield,
            compoundYield: this.compoundYield,
            yearnYield: this.yearnYield,
            strategyRegistry: this.strategyRegistry,
            savingsAccount: this.savingsAccount,
            priceOracle: this.priceOracle,
            verification: this.verification,
            repayments: this.repayments,
            extension: this.extension,
            poolFactory: this.poolFactory,
            creditLine: this.creditLine,
            pool: this.pool,
            fluxAggregator: this.fluxAggregator,
            poolToken: this.poolToken
        }
    }

    async deploy(contractName, ...params) {
        const Contract = await ethers.getContractFactory(contractName);
        const contractInstance = await Contract.deploy(...params);
        await contractInstance.deployed();

        return contractInstance;
    }

    async setupYields(strategyRegistry, yields) {
        for (let i = 0; i < yields.length; i++) {
            await strategyRegistry.connect(this.admin).addStrategy(yields[i])
        }
    }

    async setupPoolFactory(collateralToken, borrowToken) {
        //register tokens
        await this.poolFactory.connect(this.admin).updateSupportedBorrowTokens(collateralToken, true)
        await this.poolFactory.connect(this.admin).updateSupportedBorrowTokens(borrowToken, true)
        await this.poolFactory.connect(this.admin).updateSupportedCollateralTokens(collateralToken, true)
        await this.poolFactory.connect(this.admin).updateSupportedCollateralTokens(borrowToken, true)

        await this.addPriceFeed(
            borrowToken,
            collateralToken,
            this.oracle.address,
            this.oracle.address,
        )

        await this.poolFactory.connect(this.admin).setImplementations(this.pool.address, this.repayments.address, this.poolToken.address)
    }

    async addPriceFeed(
        btokenAddress,
        cTokenAddress,
        priceOracle1,
        priceOracle2,
    ) {
        const isExist = await this.priceOracle.doesFeedExist(btokenAddress, cTokenAddress)
        if (isExist) return;
        //add feed
        await this.priceOracle.connect(this.admin).setfeedAddress(btokenAddress, cTokenAddress, priceOracle1, priceOracle2)

    }

    async verifyBorrower(borrower, borrowerDetails) {
        if (!borrowerDetails)
            borrowerDetails =
                '0x0100000000000000000000000000000000000000000000000000000000000000'

        //check if registered
        const isRegistered = await this.verification.isUser(borrower);
        if (isRegistered) return;
        await this.verification.connect(this.verifier).registerUser(borrower, borrowerDetails)
    }

    async deployPool(borrower, borrowToken, collateralToken) {
        //TODO
        // const poolContract = await utils.generateAddress(web3, address.poolFactory)

        if (collateralToken.address !== ethers.constants.AddressZero) {
            await this.token.connect(borrower).approve(poolContract, config.OpenBorrowPool.collateralAmount)
        }
        //create pool
        await poolFactory
            .connect(borrower)
            .createPool(
                config.OpenBorrowPool.poolSize,
                config.OpenBorrowPool.minBorrowAmountFraction,
                borrowToken,
                collateralToken,
                config.OpenBorrowPool.collateralRatio,
                config.OpenBorrowPool.borrowRate,
                config.OpenBorrowPool.repaymentInterval,
                config.OpenBorrowPool.noOfRepaymentIntervals,
                config.OpenBorrowPool.investedTo,
                config.OpenBorrowPool.collateralAmount,
                config.OpenBorrowPool.transferFromSavingsAccount,
                encodeUserData(config.OpenBorrowPool.salt),
            )

    }
}

module.exports = Deploy;
