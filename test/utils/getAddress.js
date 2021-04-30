const { ethers } = require('ethers');
const { getSalt, getInitCodehash } = require("./utils");

const poolCompiled = require("../../build/contracts/Pool/Pool.sol/Pool.json");
const proxyCompiled = require("../../build/contracts/Proxy.sol/SublimeProxy.json");

let config = require("../../config/config.json");

const interface = new ethers.utils.Interface(poolCompiled.abi)

const initializeFragement = interface.getFunction('initialize')

const getPoolAddress = (network, borrower, token1, token2, strategy, poolFactory, salt, poolLogic) => {
    let localConfig = config[network];
    const poolData = interface.encodeFunctionData(initializeFragement, [
        localConfig.OpenBorrowPool.poolSize,
        localConfig.OpenBorrowPool.minBorrowAmountFraction,
        borrower,
        token1,
        token2,
        localConfig.OpenBorrowPool.collateralRatio,
        localConfig.OpenBorrowPool.borrowRate,
        localConfig.OpenBorrowPool.repaymentInterval,
        localConfig.OpenBorrowPool.noOfRepaymentIntervals,
        strategy,
        localConfig.OpenBorrowPool.collateralAmount,
        localConfig.OpenBorrowPool.transferFromSavingsAccount,
        localConfig.pool.matchCollateralRatioInterval,
        localConfig.pool.collectionPeriod,
    ]);
    
    const poolAddress = ethers.utils.getCreate2Address(
        poolFactory,
        getSalt(ethers, borrower, salt),
        getInitCodehash(
            ethers,
            proxyCompiled.bytecode,
            poolLogic,
            poolData,
            '0x0000000000000000000000000000000000000001',
        ),
    );
    return poolAddress;
}

module.exports =  { getPoolAddress };