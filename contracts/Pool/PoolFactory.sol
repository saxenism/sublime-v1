// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "../Proxy.sol";
import "../interfaces/IPoolFactory.sol";
import "../interfaces/IBorrower.sol";
import "../interfaces/IStrategyRegistry.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolFactory is Initializable, OwnableUpgradeable, IPoolFactory {

    struct Limits {
        // TODO: Optimize to uint128 or even less
        uint256 min;
        uint256 max;
    }

    bytes4 public initializeFunctionId; //  bytes4(keccak256("initialize(uint256,address,address,address,uint256,uint256,uint256,uint256,bool)"))
    address public poolImpl;
    address public borrowerRegistry;
    address public strategyRegistry;
    address public override savingsAccount;
    address public override repaymentImpl;
    address public override priceOracle;

    uint256 public override collectionPeriod;
    uint256 public override matchCollateralRatioInterval;
    uint256 public override marginCallDuration;
    uint256 public override collateralVolatilityThreshold;
    uint256 public override gracePeriodPenaltyFraction;
    uint256 public override liquidatorRewardFraction;

    mapping(address => bool) isBorrowToken;
    mapping(address => bool) isCollateralToken;
    

    mapping(address => bool) public registry;

    Limits poolSizeLimit;
    Limits collateralRatioLimit;
    Limits borrowRateLimit;
    Limits loanDurationLimit;
    Limits repaymentIntervalLimit;

    event InitializeFunctionUpdated(bytes4 updatedFunctionId);
    event PoolLogicUpdated(address updatedPoolLogic);
    event BorrowerRegistryUpdated(address updatedBorrowerRegistry);
    event StrategyRegistryUpdated(address updatedStrategyRegistry);
    event RepaymentImplUpdated(address updatedRepaymentImpl);
    event PriceOracleUpdated(address updatedPriceOracle);
    event CollectionPeriodUpdated(uint256 updatedCollectionPeriod);
    event MatchCollateralRatioIntervalUpdated(uint256 updatedMatchCollateralRatioInterval);
    event MarginCallDurationUpdated(uint256 updatedMarginCallDuration);
    event CollateralVolatilityThresholdUpdated(uint256 updatedCollateralVolatilityThreshold);
    event GracePeriodPenaltyFractionUpdated(uint256 updatedGracePeriodPenaltyFraction);
    event LiquidatorRewardFractionUpdated(uint256 updatedLiquidatorRewardFraction);

    modifier onlyPool() {
        require(registry[msg.sender], "PoolFactory::onlyPool - Only pool can destroy itself");
        _;
    }

    modifier onlyBorrower() {
        require(IBorrower(borrowerRegistry).isBorrower(msg.sender), "PoolFactory::onlyBorrower - Only a valid Borrower can create Pool");
        _;
    }

    function owner() override(IPoolFactory, OwnableUpgradeable) public view returns(address) {
        return OwnableUpgradeable.owner();
    }

    function initialize(
        address _poolImpl, 
        address _borrowerRegistry, 
        address _strategyRegistry, 
        address _admin, 
        uint256 _collectionPeriod,
        uint256 _matchCollateralRatioInterval,
        uint256 _marginCallDuration,
        uint256 _collateralVolatilityThreshold,
        uint256 _gracePeriodPenaltyFraction,
        bytes4 _initializeFunctionId,
        uint256 _liquidatorRewardFraction
    ) external initializer {
        OwnableUpgradeable.__Ownable_init();
        OwnableUpgradeable.transferOwnership(_admin);
        poolImpl = _poolImpl;
        borrowerRegistry = _borrowerRegistry;
        strategyRegistry = _strategyRegistry;
        collectionPeriod = _collectionPeriod;
        matchCollateralRatioInterval = _matchCollateralRatioInterval;
        marginCallDuration = _marginCallDuration;
        collateralVolatilityThreshold = _collateralVolatilityThreshold;
        gracePeriodPenaltyFraction = _gracePeriodPenaltyFraction;
        initializeFunctionId = _initializeFunctionId;
        liquidatorRewardFraction = _liquidatorRewardFraction;
    }

    function createPool(
        uint256 _poolSize,
        address _borrowTokenType,
        address _collateralTokenType,
        uint256 _collateralRatio,
        uint256 _borrowRate,
        uint256 _loanDuration,
        uint256 _repaymentInterval,
        address _investedTo
    ) external onlyBorrower {
        require(isBorrowToken[_borrowTokenType], "PoolFactory::createPool - Invalid borrow token type");
        require(isCollateralToken[_collateralTokenType], "PoolFactory::createPool - Invalid collateral token type");
        require(IStrategyRegistry(strategyRegistry).registry(_investedTo), "PoolFactory::createPool - Invalid strategy");
        require(isWithinLimits(_poolSize, poolSizeLimit.min, poolSizeLimit.max), "PoolFactory::createPool - PoolSize not within limits");
        require(isWithinLimits(_collateralRatio, collateralRatioLimit.min, collateralRatioLimit.max), "PoolFactory::createPool - Collateral Ratio not within limits");
        require(isWithinLimits(_borrowRate, borrowRateLimit.min, borrowRateLimit.max), "PoolFactory::createPool - Borrow rate not within limits");
        require(isWithinLimits(_loanDuration, loanDurationLimit.min, loanDurationLimit.max), "PoolFactory::createPool - Loan duration not within limits");
        require(isWithinLimits(_repaymentInterval, repaymentIntervalLimit.min, repaymentIntervalLimit.max), "PoolFactory::createPool - Repayment interval not within limits");
        bytes memory data = abi.encodeWithSelector(initializeFunctionId, _poolSize, msg.sender, _borrowTokenType, _collateralTokenType, _collateralRatio, _borrowRate, _loanDuration, _repaymentInterval);
        // TODO: Setting 0x00 as admin, so that it is not upgradable. Remove the upgradable functionality to optimize
        address pool = address(new SublimeProxy(poolImpl, address(0), data));
        registry[pool] = true;
    }

    function isWithinLimits(uint256 _value, uint256 _min, uint256 _max) internal pure returns(bool) {
        if(_min != 0 && _max != 0) {
            return (_value >= _min && _value <= _max);
        } else if(_min != 0) {
            return (_value >= _min);
        } else if(_max != 0) {
            return (_value <= _max);
        } else {
            return true;
        }
    }

    function destroyPool() public onlyPool {
        delete registry[msg.sender];
    }

    function updateInitializeFunctionId(bytes4 _functionId) external onlyOwner {
        initializeFunctionId = _functionId;
        emit InitializeFunctionUpdated(_functionId);
    }

    function updatePoolLogic(address _poolLogic) external onlyOwner {
        poolImpl = _poolLogic;
        emit PoolLogicUpdated(_poolLogic);
    }

    function updateBorrowerRegistry(address _borrowerRegistry) external onlyOwner {
        borrowerRegistry = _borrowerRegistry;
        emit BorrowerRegistryUpdated(_borrowerRegistry);
    }

    function updateStrategyRegistry(address _strategyRegistry) external onlyOwner {
        strategyRegistry = _strategyRegistry;
        emit StrategyRegistryUpdated(_strategyRegistry);
    }

    function updateRepaymentImpl(address _repaymentImpl) external onlyOwner {
        repaymentImpl = _repaymentImpl;
        emit RepaymentImplUpdated(_repaymentImpl);
    }

    function updatePriceoracle(address _priceOracle) external onlyOwner {
        priceOracle = _priceOracle;
        emit PriceOracleUpdated(_priceOracle);
    }

    function updateCollectionPeriod(uint256 _collectionPeriod) external onlyOwner {
        collectionPeriod = _collectionPeriod;
        emit CollectionPeriodUpdated(_collectionPeriod);
    }

    function updateMatchCollateralRatioInterval(uint256 _matchCollateralRatioInterval) external onlyOwner {
        matchCollateralRatioInterval = _matchCollateralRatioInterval;
        emit MatchCollateralRatioIntervalUpdated(_matchCollateralRatioInterval);
    }

    function updateMarginCallDuration(uint256 _marginCallDuration) external onlyOwner {
        marginCallDuration = _marginCallDuration;
        emit MarginCallDurationUpdated(_marginCallDuration);
    }

    function updateCollateralVolatilityThreshold(uint256 _collateralVolatilityThreshold) external onlyOwner {
        collateralVolatilityThreshold = _collateralVolatilityThreshold;
        emit CollateralVolatilityThresholdUpdated(_collateralVolatilityThreshold);
    }

    function updateGracePeriodPenaltyFraction(uint256 _gracePeriodPenaltyFraction) external onlyOwner {
        gracePeriodPenaltyFraction = _gracePeriodPenaltyFraction;
        emit GracePeriodPenaltyFractionUpdated(_gracePeriodPenaltyFraction);
    }

    function updateLiquidatorRewardFraction(uint256 _liquidatorRewardFraction) external onlyOwner {
        liquidatorRewardFraction = _liquidatorRewardFraction;
        emit LiquidatorRewardFractionUpdated(_liquidatorRewardFraction);
    }
}