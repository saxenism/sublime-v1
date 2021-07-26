import { Network } from 'hardhat/types';
import { BytesLike, ethers } from 'ethers';
import { Address } from 'hardhat-deploy/dist/types';

export function getRandomFromArray<T>(items: T[]): T {
    return items[Math.floor(Math.random() * items.length)];
}

export async function incrementChain(network: Network, blocks: number, blockTime: number = 15000) {
    await network.provider.request({
        method: 'evm_increaseTime',
        params: [blocks * blockTime],
    });

    for (let index = 0; index < blocks; index++) {
        await network.provider.request({
            method: 'evm_mine',
            params: [],
        });
    }
    return;
}

import poolContractMeta from '../artifacts/contracts/Pool/Pool.sol/Pool.json';
import proxyMeta from '../artifacts/contracts/Proxy.sol/SublimeProxy.json';

import { createPoolParams, testPoolFactoryParams } from './constants';

const _interface = new ethers.utils.Interface(poolContractMeta.abi);
const initializeFragement = _interface.getFunction('initialize');

export async function getPoolAddress(
    borrower: Address,
    borrowToken: Address,
    collateralToken: Address,
    strategy: Address,
    poolFactory: Address,
    salt: BytesLike,
    poolLogic: Address,
    transferFromSavingsAccount: Boolean,
    {
        _poolSize = createPoolParams._poolSize,
        _minborrowAmount = createPoolParams._minborrowAmount,
        _collateralRatio = createPoolParams._collateralRatio,
        _borrowRate = createPoolParams._borrowRate,
        _repaymentInterval = createPoolParams._repaymentInterval,
        _noOfRepaymentIntervals = createPoolParams._noOfRepaymentIntervals,
        _collateralAmount = createPoolParams._collateralAmount,
        _matchCollateralRatioInterval = testPoolFactoryParams._matchCollateralRatioInterval,
        _collectionPeriod = testPoolFactoryParams._collectionPeriod,
    }
) {
    const poolData = _interface.encodeFunctionData(initializeFragement, [
        _poolSize,
        _minborrowAmount,
        borrower,
        borrowToken,
        collateralToken,
        _collateralRatio,
        _borrowRate,
        _repaymentInterval,
        _noOfRepaymentIntervals,
        strategy,
        _collateralAmount,
        transferFromSavingsAccount,
        _matchCollateralRatioInterval,
        _collectionPeriod,
    ]);

    const poolAddress = ethers.utils.getCreate2Address(
        poolFactory,
        getSalt(borrower, salt),
        getInitCodehash(proxyMeta.bytecode, poolLogic, poolData, '0x0000000000000000000000000000000000000001')
    );
    return poolAddress;
}

function getSalt(address: Address, salt: BytesLike) {
    return ethers.utils.solidityKeccak256(['bytes32', 'address'], [salt, address]);
}

function getInitCodehash(proxyBytecode: BytesLike, poolImplAddr: Address, poolData: BytesLike, admin: Address) {
    const initialize = ethers.utils.defaultAbiCoder.encode(['address', 'address', 'bytes'], [poolImplAddr, admin, poolData]);
    const encodedData = proxyBytecode + initialize.replace('0x', '');
    return ethers.utils.keccak256(encodedData);
}

function print(data: any) {
    console.log(JSON.stringify(data, null, 4));
}
