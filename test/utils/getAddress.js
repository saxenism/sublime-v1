const { ethers } = require('ethers');
const { encodeUserData, getSalt, getInitCodehash } = require("./utils");

const poolCompiled = require("../../build/contracts/Pool.json");
const proxyCompiled = require("../../artifacts/contracts/Proxy.sol/SublimeProxy.json");

let config = require("../../config/config.json");

const interface = new ethers.utils.Interface(poolCompiled.abi)

const initializeFragement = interface.getFunction('initialize')

const getPoolAddress = (network, borrower, token1, token2, strategy, poolFactory, salt, poolLogic) => {
    config = config[network];
    const poolData = interface.encodeFunctionData(initializeFragement, [
        config.OpenBorrowPool.poolSize,
        config.OpenBorrowPool.minBorrowAmountFraction,
        borrower,
        token1,
        token2,
        config.OpenBorrowPool.collateralRatio,
        config.OpenBorrowPool.borrowRate,
        config.OpenBorrowPool.repaymentInterval,
        config.OpenBorrowPool.noOfRepaymentIntervals,
        strategy,
        config.OpenBorrowPool.collateralAmount,
        config.OpenBorrowPool.transferFromSavingsAccount,
        config.pool.matchCollateralRatioInterval,
        config.pool.collectionPeriod,
    ]);
    console.log(poolFactory, getSalt(ethers, borrower, salt),
    getInitCodehash(
        ethers,
        proxyCompiled.bytecode,
        poolLogic,
        poolData,
        '0x0000000000000000000000000000000000000001',
    ));
    
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
    console.log("poolAddress", poolAddress)
    return poolAddress;
}

module.exports =  { getPoolAddress };