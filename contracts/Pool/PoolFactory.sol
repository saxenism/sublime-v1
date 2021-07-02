// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "../Proxy.sol";
import "../interfaces/IPoolFactory.sol";
import "../interfaces/IVerification.sol";
import "../interfaces/IStrategyRegistry.sol";
import "../interfaces/IRepayment.sol";
import "../interfaces/IPriceOracle.sol";
import "./PoolToken.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolFactory is Initializable, OwnableUpgradeable, IPoolFactory {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct Limits {
        // TODO: Optimize to uint128 or even less
        uint256 min;
        uint256 max;
    }

    // TODO contract addresses should end with Impl
    bytes4 public poolInitFuncSelector; //  bytes4(keccak256("initialize(uint256,address,address,address,uint256,uint256,uint256,uint256,bool)"))
    bytes4 public poolTokenInitFuncSelector;
    address public poolImpl;
    address public poolTokenImpl;
    address public userRegistry;
    address public strategyRegistry;
    address public override extension;
    address public override repaymentImpl;
    address public override priceOracle;
    address public override savingsAccount;

    uint256 public override collectionPeriod;
    uint256 public override matchCollateralRatioInterval;
    uint256 public override marginCallDuration;
    uint256 public override collateralVolatilityThreshold;
    uint256 public override gracePeriodPenaltyFraction;
    uint256 public override liquidatorRewardFraction;
    uint256 public override votingPassRatio;
    uint256 public override gracePeriodFraction;
    uint256 public override poolCancelPenalityFraction;

    mapping(address => bool) isBorrowToken;
    mapping(address => bool) isCollateralToken;

    mapping(address => bool) public override openBorrowPoolRegistry;

    Limits poolSizeLimit;
    Limits collateralRatioLimit;
    Limits borrowRateLimit;
    Limits repaymentIntervalLimit;
    Limits noOfRepaymentIntervalsLimit;

    event PoolCreated(address pool, address borrower, address poolToken);
    event PoolInitSelectorUpdated(bytes4 updatedSelector);
    event PoolTokenInitFuncSelector(bytes4 updatedSelector);
    event PoolLogicUpdated(address updatedPoolLogic);
    event UserRegistryUpdated(address updatedBorrowerRegistry);
    event StrategyRegistryUpdated(address updatedStrategyRegistry);
    event RepaymentImplUpdated(address updatedRepaymentImpl);
    event PoolTokenImplUpdated(address updatedPoolTokenImpl);
    event PriceOracleUpdated(address updatedPriceOracle);
    event CollectionPeriodUpdated(uint256 updatedCollectionPeriod);
    event MatchCollateralRatioIntervalUpdated(
        uint256 updatedMatchCollateralRatioInterval
    );
    event MarginCallDurationUpdated(uint256 updatedMarginCallDuration);
    event CollateralVolatilityThresholdUpdated(
        uint256 updatedCollateralVolatilityThreshold
    );
    event GracePeriodPenaltyFractionUpdated(
        uint256 updatedGracePeriodPenaltyFraction
    );
    event LiquidatorRewardFractionUpdated(
        uint256 updatedLiquidatorRewardFraction
    );
    event LimitsUpdated(string limitType, uint256 max, uint256 min);
    event BorrowTokenUpdated(address borrowToken, bool isSupported);
    event CollateralTokenUpdated(address collateralToken, bool isSupported);

    modifier onlyPool() {
        require(
            openBorrowPoolRegistry[msg.sender],
            "PoolFactory::onlyPool - Only pool can destroy itself"
        );
        _;
    }

    modifier onlyBorrower() {
        require(
            IVerification(userRegistry).isUser(msg.sender),
            "PoolFactory::onlyBorrower - Only a valid Borrower can create Pool"
        );
        _;
    }

    function owner()
        public
        view
        override(IPoolFactory, OwnableUpgradeable)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    function initialize(
        address _userRegistry,
        address _strategyRegistry,
        address _admin,
        uint256 _collectionPeriod,
        uint256 _matchCollateralRatioInterval,
        uint256 _marginCallDuration,
        uint256 _collateralVolatilityThreshold,
        uint256 _gracePeriodPenaltyFraction,
        bytes4 _poolInitFuncSelector,
        bytes4 _poolTokenInitFuncSelector,
        uint256 _liquidatorRewardFraction,
        address _priceOracle,
        address _savingsAccount,
        address _extension,
        uint256 _poolCancelPenalityFraction
    ) external initializer {
        {
            OwnableUpgradeable.__Ownable_init();
            OwnableUpgradeable.transferOwnership(_admin);
        }
        userRegistry = _userRegistry;
        strategyRegistry = _strategyRegistry;

        collectionPeriod = _collectionPeriod;
        matchCollateralRatioInterval = _matchCollateralRatioInterval;
        marginCallDuration = _marginCallDuration;
        collateralVolatilityThreshold = _collateralVolatilityThreshold;
        gracePeriodPenaltyFraction = _gracePeriodPenaltyFraction;
        poolInitFuncSelector = _poolInitFuncSelector;
        poolTokenInitFuncSelector = _poolTokenInitFuncSelector;
        liquidatorRewardFraction = _liquidatorRewardFraction;
        priceOracle = _priceOracle;
        savingsAccount = _savingsAccount;
        extension = _extension;
        poolCancelPenalityFraction = _poolCancelPenalityFraction;
    }

    function setImplementations(
        address _poolImpl,
        address _repaymentImpl,
        address _poolTokenImpl
    ) external onlyOwner {
        poolImpl = _poolImpl;
        repaymentImpl = _repaymentImpl;
        poolTokenImpl = _poolTokenImpl;

        emit PoolLogicUpdated(_poolImpl);
        emit RepaymentImplUpdated(_repaymentImpl);
        emit PoolTokenImplUpdated(_poolTokenImpl);
    }

    function createPool(
        uint256 _poolSize,
        uint256 _minBorrowAmount,
        address _borrowTokenType,
        address _collateralTokenType,
        uint256 _collateralRatio,
        uint256 _borrowRate,
        uint256 _repaymentInterval,
        uint256 _noOfRepaymentIntervals,
        address _poolSavingsStrategy,
        uint256 _collateralAmount,
        bool _transferFromSavingsAccount,
        bytes32 _salt
    ) external payable onlyBorrower {
        require(
            _minBorrowAmount <= _poolSize,
            "PoolFactory::createPool - invalid min borrow amount"
        );
        require(
            collateralVolatilityThreshold <= _collateralRatio,
            "PoolFactory:createPool - Invalid collateral ratio"
        );
        require(
            isBorrowToken[_borrowTokenType],
            "PoolFactory::createPool - Invalid borrow token type"
        );
        require(
            isCollateralToken[_collateralTokenType],
            "PoolFactory::createPool - Invalid collateral token type"
        );
        address[] memory tokens = new address[](2);
        tokens[0] = _collateralTokenType;
        tokens[1] = _borrowTokenType;
        require(
            IPriceOracle(priceOracle).doesFeedExist(tokens),
            "PoolFactory::createPool - Price feed doesn't support token pair"
        );
        require(
            IStrategyRegistry(strategyRegistry).registry(_poolSavingsStrategy),
            "PoolFactory::createPool - Invalid strategy"
        );
        require(
            isWithinLimits(_poolSize, poolSizeLimit.min, poolSizeLimit.max),
            "PoolFactory::createPool - PoolSize not within limits"
        );
        require(
            isWithinLimits(
                _collateralRatio,
                collateralRatioLimit.min,
                collateralRatioLimit.max
            ),
            "PoolFactory::createPool - Collateral Ratio not within limits"
        );
        require(
            isWithinLimits(
                _borrowRate,
                borrowRateLimit.min,
                borrowRateLimit.max
            ),
            "PoolFactory::createPool - Borrow rate not within limits"
        );
        require(
            isWithinLimits(
                _noOfRepaymentIntervals,
                noOfRepaymentIntervalsLimit.min,
                noOfRepaymentIntervalsLimit.max
            ),
            "PoolFactory::createPool - Loan duration not within limits"
        );
        require(
            isWithinLimits(
                _repaymentInterval,
                repaymentIntervalLimit.min,
                repaymentIntervalLimit.max
            ),
            "PoolFactory::createPool - Repayment interval not within limits"
        );
        bytes memory data =
            abi.encodeWithSelector(
                poolInitFuncSelector,
                _poolSize,
                _minBorrowAmount,
                msg.sender,
                _borrowTokenType,
                _collateralTokenType,
                _collateralRatio,
                _borrowRate,
                _repaymentInterval,
                _noOfRepaymentIntervals,
                _poolSavingsStrategy,
                _collateralAmount,
                _transferFromSavingsAccount,
                matchCollateralRatioInterval,
                collectionPeriod
            );

        bytes32 salt = keccak256(abi.encodePacked(_salt, msg.sender));
        bytes memory bytecode =
            abi.encodePacked(
                type(SublimeProxy).creationCode,
                abi.encode(poolImpl, address(0x01), data)
            );
        uint256 amount =
            _collateralTokenType == address(0) ? _collateralAmount : 0;

        address pool = _deploy(amount, salt, bytecode);

        bytes memory tokenData =
            abi.encodeWithSelector(
                poolTokenInitFuncSelector,
                "Open Borrow Pool Tokens",
                "OBPT",
                pool
            );
        address poolToken =
            address(new SublimeProxy(poolTokenImpl, address(0), tokenData));
        IPool(pool).setPoolToken(poolToken);
        openBorrowPoolRegistry[pool] = true;
        emit PoolCreated(pool, msg.sender, poolToken);
    }

    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `amount`.
     * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
     */
    function _deploy(
        uint256 amount,
        bytes32 salt,
        bytes memory bytecode
    ) internal returns (address addr) {
        require(bytecode.length != 0, "Create2: bytecode length is zero");
        // solhint-disable-next-line no-inline-assembly
        assembly {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "Create2: Failed on deploy");
    }

    function isWithinLimits(
        uint256 _value,
        uint256 _min,
        uint256 _max
    ) internal pure returns (bool) {
        if (_min != 0 && _max != 0) {
            return (_value >= _min && _value <= _max);
        } else if (_min != 0) {
            return (_value >= _min);
        } else if (_max != 0) {
            return (_value <= _max);
        } else {
            return true;
        }
    }

    function destroyPool() public onlyPool {
        delete openBorrowPoolRegistry[msg.sender];
    }

    function updateSupportedBorrowTokens(
        address _borrowToken,
        bool _isSupported
    ) external onlyOwner {
        isBorrowToken[_borrowToken] = _isSupported;
        emit BorrowTokenUpdated(_borrowToken, _isSupported);
    }

    function updateSupportedCollateralTokens(
        address _collateralToken,
        bool _isSupported
    ) external onlyOwner {
        isCollateralToken[_collateralToken] = _isSupported;
        emit CollateralTokenUpdated(_collateralToken, _isSupported);
    }

    function updatepoolInitFuncSelector(bytes4 _functionId) external onlyOwner {
        poolInitFuncSelector = _functionId;
        emit PoolInitSelectorUpdated(_functionId);
    }

    function updatePoolTokenInitFuncSelector(bytes4 _functionId)
        external
        onlyOwner
    {
        poolTokenInitFuncSelector = _functionId;
        emit PoolTokenInitFuncSelector(_functionId);
    }

    function updatePoolLogic(address _poolLogic) external onlyOwner {
        poolImpl = _poolLogic;
        emit PoolLogicUpdated(_poolLogic);
    }

    function updateUserRegistry(address _userRegistry) external onlyOwner {
        userRegistry = _userRegistry;
        emit UserRegistryUpdated(_userRegistry);
    }

    function updateStrategyRegistry(address _strategyRegistry)
        external
        onlyOwner
    {
        strategyRegistry = _strategyRegistry;
        emit StrategyRegistryUpdated(_strategyRegistry);
    }

    function updateRepaymentImpl(address _repaymentImpl) external onlyOwner {
        repaymentImpl = _repaymentImpl;
        emit RepaymentImplUpdated(_repaymentImpl);
    }

    function updatePoolTokenImpl(address _poolTokenImpl) external onlyOwner {
        poolTokenImpl = _poolTokenImpl;
        emit PoolTokenImplUpdated(_poolTokenImpl);
    }

    function updatePriceoracle(address _priceOracle) external onlyOwner {
        priceOracle = _priceOracle;
        emit PriceOracleUpdated(_priceOracle);
    }

    function updateCollectionPeriod(uint256 _collectionPeriod)
        external
        onlyOwner
    {
        collectionPeriod = _collectionPeriod;
        emit CollectionPeriodUpdated(_collectionPeriod);
    }

    function updateMatchCollateralRatioInterval(
        uint256 _matchCollateralRatioInterval
    ) external onlyOwner {
        matchCollateralRatioInterval = _matchCollateralRatioInterval;
        emit MatchCollateralRatioIntervalUpdated(_matchCollateralRatioInterval);
    }

    function updateMarginCallDuration(uint256 _marginCallDuration)
        external
        onlyOwner
    {
        marginCallDuration = _marginCallDuration;
        emit MarginCallDurationUpdated(_marginCallDuration);
    }

    function updateCollateralVolatilityThreshold(
        uint256 _collateralVolatilityThreshold
    ) external onlyOwner {
        collateralVolatilityThreshold = _collateralVolatilityThreshold;
        emit CollateralVolatilityThresholdUpdated(
            _collateralVolatilityThreshold
        );
    }

    function updateGracePeriodPenaltyFraction(
        uint256 _gracePeriodPenaltyFraction
    ) external onlyOwner {
        gracePeriodPenaltyFraction = _gracePeriodPenaltyFraction;
        emit GracePeriodPenaltyFractionUpdated(_gracePeriodPenaltyFraction);
    }

    function updateLiquidatorRewardFraction(uint256 _liquidatorRewardFraction)
        external
        onlyOwner
    {
        liquidatorRewardFraction = _liquidatorRewardFraction;
        emit LiquidatorRewardFractionUpdated(_liquidatorRewardFraction);
    }

    function updatePoolSizeLimit(uint256 _min, uint256 _max)
        external
        onlyOwner
    {
        poolSizeLimit = Limits(_min, _max);
        emit LimitsUpdated("PoolSize", _min, _max);
    }

    function updateCollateralRatioLimit(uint256 _min, uint256 _max)
        external
        onlyOwner
    {
        collateralRatioLimit = Limits(_min, _max);
        emit LimitsUpdated("CollateralRatio", _min, _max);
    }

    function updateBorrowRateLimit(uint256 _min, uint256 _max)
        external
        onlyOwner
    {
        borrowRateLimit = Limits(_min, _max);
        emit LimitsUpdated("BorrowRate", _min, _max);
    }

    function updateRepaymentIntervalLimit(uint256 _min, uint256 _max)
        external
        onlyOwner
    {
        repaymentIntervalLimit = Limits(_min, _max);
        emit LimitsUpdated("RepaymentInterval", _min, _max);
    }

    function updateNoOfRepaymentIntervalsLimit(uint256 _min, uint256 _max)
        external
        onlyOwner
    {
        noOfRepaymentIntervalsLimit = Limits(_min, _max);
        emit LimitsUpdated("NoOfRepaymentIntervals", _min, _max);
    }
}
