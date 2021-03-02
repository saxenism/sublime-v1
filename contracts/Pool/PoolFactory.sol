// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "../Proxy.sol";
import "../interfaces/IBorrower.sol";
import "../interfaces/IStrategyRegistry.sol";
// import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolFactory is Initializable, OwnableUpgradeable {
    // TODO: Add setter for each of the variables
    bytes4 initializeFunctionId = bytes4(keccak256("initialize(uint256,address,address,address,uint256,uint256,uint256,uint256,bool)"));
    address public poolImpl;
    address public borrowerRegistry;
    address public strategyRegistry;
    address public repaymentImpl;
    address public priceOracle;

    uint256 public collectionPeriod;
    uint256 public matchCollateralRatioInterval;
    uint256 public marginCallDuration;
    uint256 public collateralVolatilityThreshold;
    mapping(address => bool) public registry;

    modifier onlyPool(address _pool) {
        require(registry[_pool], "PoolFactory::onlyPool - Only pool can destroy itself");
        _;
    }

    modifier onlyBorrower() {
        require(IBorrower(borrowerRegistry).isBorrower(msg.sender), "PoolFactory::onlyBorrower - Only a valid Borrower can create Pool");
        _;
    }

    function initialize(
        address _poolImpl, 
        address _borrowerRegistry, 
        address _strategyRegistry, 
        address _admin, 
        uint256 _collectionPeriod,
        uint256 _matchCollateralRatioInterval,
        uint256 _marginCallDuration,
        uint256 _collateralVolatilityThreshold
    ) public initializer {
        
    }

    function createPool(
        uint256 _poolSize,
        address _borrowTokenType,
        address _collateralTokenType,
        uint256 _collateralRatio,
        uint256 _borrowRate,
        uint256 _loanDuration,
        uint256 _repaymentInterval,
        address _investedTo,
        bool _repaymentType
    ) public onlyBorrower {
        
    }

    function destroyPool() public onlyPool(msg.sender) {
        
    }
}