import { BigNumber } from '@ethersproject/bignumber';
import { Address } from 'hardhat-deploy/dist/types';

export const depositValueToTest: BigNumber = BigNumber.from('1000000000000000000'); // 1 ETH (or) 10^18 Tokens
export const zeroAddress: Address = '0x0000000000000000000000000000000000000000';

export const aaveYieldParams = {
    _wethGateway: '0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04',
    _protocolDataProvider: '0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d',
    _lendingPoolAddressesProvider: '0xb53c1a33016b2dc2ff3653530bff1848a515c8c5',
};

export const ETH_Yearn_Protocol_Address = '0xe1237aa7f535b0cc33fd973d66cbf830354d16c7'; // TODO: To be upgraded to v2

export const Binance7 = '0xbe0eb53f46cd790cd13851d5eff43d12404d33e8';
export const WhaleAccount = '0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503';
export const WBTCWhale = '0x28C6c06298d514Db089934071355E5743bf21d60'; // Binance 14
export const DAI_Yearn_Protocol_Address = '0xacd43e627e64355f1861cec6d3a6688b31a6f952'; // TODO: To be upgraded to v2

export const LINK_Yearn_Protocol_Address = '0x881b06da56bb5675c54e4ed311c21e54c5025298'; // @prateek to check if update needed in upgrade v2

export const aLink = '0xa06bC25B5805d5F8d82847D191Cb4Af5A3e873E0';

const collateralRatio = BigNumber.from(60).mul(BigNumber.from(10).pow(28));
const poolSize = BigNumber.from('100000000000000000000'); // 100e18 dai

export const createPoolParams = {
    _poolSize: poolSize,
    _borrowAmountRequested: depositValueToTest,
    _minborrowAmount: BigNumber.from('10000000000000000000'), // 10e18
    _idealCollateralRatio: collateralRatio,
    _collateralRatio: collateralRatio,
    _borrowRate: BigNumber.from(1).mul(BigNumber.from(10).pow(28)),
    _repaymentInterval: BigNumber.from(1000),
    _noOfRepaymentIntervals: BigNumber.from(25),
    _collateralAmount: BigNumber.from('3000000000000000000000'), // 3000e18
    _collateralAmountForUNI: BigNumber.from('10000000000000000000'), // 1 UNI
    _loanWithdrawalDuration: BigNumber.from(15000000),
    _collectionPeriod: BigNumber.from(5000000),
};

// address _borrowTokenType,
// address _collateralTokenType,
// address _poolSavingsStrategy,
// bool _transferFromSavingsAccount,
// bytes32 _salt

export const testPoolFactoryParams = {
    _collectionPeriod: BigNumber.from(10000),
    _matchCollateralRatioInterval: BigNumber.from(200),
    _marginCallDuration: BigNumber.from(300),
    _collateralVolatilityThreshold: BigNumber.from(20).mul(BigNumber.from(10).pow(28)),
    _gracePeriodPenaltyFraction: BigNumber.from(5).mul(BigNumber.from(10).pow(28)),
    _liquidatorRewardFraction: BigNumber.from(15).mul(BigNumber.from(10).pow(28)),
    _poolInitFuncSelector: '0x272edaf2',
    _poolTokenInitFuncSelector: '0x077f224a',
    _poolCancelPenalityFraction: BigNumber.from(10).mul(BigNumber.from(10).pow(28)),
};

export const repaymentParams = {
    gracePenalityRate: BigNumber.from(10).mul(BigNumber.from(10).pow(28)),
    gracePeriodFraction: BigNumber.from(10).mul(BigNumber.from(10).pow(28)),
};

export const extensionParams = {
    votingPassRatio: BigNumber.from(10).pow(28).mul(50),
};

// Pool Factory inputs tro be manually added
// bytes4 _poolInitFuncSelector,
// bytes4 _poolTokenInitFuncSelector,

// Pool inputs to be manullay added
// address _borrower,
// address _borrowAsset,
// address _collateralAsset,
// address _poolSavingsStrategy,
// bool _transferFromSavingsAccount,

export const OperationalAmounts = {
    _amountLent: BigNumber.from(1000000),
};

export const ChainLinkAggregators = {
    'LINK/USD': '0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c',
    'DAI/USD': '0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9',
    'ETH/USD': '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
    'BTC/USD': '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c',
    'UNI/USD': '0x553303d460EE0afB37EdFf9bE42922D8FF63220e',
    'USDC/USD': '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6',
    'INCH/USD': '0xc929ad75b72593967de83e7f7cda0493458261d9',
    'COMP/USD': '0xdbd020caef83efd542f4de03e3cf0c28a4428bd5',
    'HEGIC/USD': '0xbfc189ac214e6a4a35ebc281ad15669619b75534',
    'YFI/USD': '0xa027702dbb89fbd58938e4324ac03b58d812b0e1',
};
