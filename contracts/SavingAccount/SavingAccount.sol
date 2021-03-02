// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./SavingAccountStorage.sol";
import "../interfaces/IYield.sol";
import "../interfaces/IPool.sol";


/**
 * @title Savings account contract with Methods related to savings account
 * @notice Implements the functions related to savings account
 * @author Sublime
 **/

contract SavingAccount is SavingAccountStorage, Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /**
     * @dev emits when user deposit asset to Saving Account
     * @param user address of the user who deposited into saving account
     * @param amount amount of the asset deposited
     * @param asset address of the asset deposited
     **/
    event deposited(address user, uint256 amount, address asset);

    /**
     * @dev emits when user withdraw asset from Saving Account
     * @param user address of the user who withdrawn from saving account
     * @param amount amount of the asset withdrawn
     * @param asset address of the asset withdrawn
     * @param strategy address of the asset withdrawn
     **/
    event withDrawn(
        address user,
        uint256 amount,
        address asset,
        uint256 strategy
    );

    // TODO Add events for add, remove and update strategies

    /**
     * @dev initialize the contract
     * @param _owner address of the owner of the savings account contract
     **/
    function initialize(address _owner, uint256 _maxStrategies) public initializer {
        __Ownable_init();
        super.transferOwnership(_owner);
        maxStrategies = _maxStrategies;
    }

    /**
     * @dev Add strategies to invest in. Please ensurer that number of strategies are less than maxStrategies.
     * @param _strategy address of the owner of the savings account contract
     **/
    function addStrategy(address _strategy) external onlyOwner {
        require(strategies.length.add(1) <= maxStrategies, "SavingAccount::removeStrategy - Can't add more strategies");
        strategies.push(_strategy);
    }

    /**
     * @dev Remove strategy to invest in.
     * @param _strategyIndex Index of the strategy to remove
     **/
    function removeStrategy(uint256 _strategyIndex) external onlyOwner {
        strategies[_strategyIndex] = strategies[strategies.length.sub(1, "SavingAccount::removeStrategy - No strategies exist")];
        strategies.pop();
    }

    /**
     * @dev Remove strategy to invest in.
     * @param _strategyIndex Index of the strategy to remove
     * @param _oldStrategy Strategy that is to be removed
     * @param _newStrategy Updated strategy
     **/
    function updateStrategy(uint256 _strategyIndex, address _oldStrategy, address _newStrategy) external onlyOwner {
        require(strategies[_strategyIndex] == _oldStrategy, "SavingAccount::updateStrategy - index to update and strategy address don't match");
        strategies[_strategyIndex] = _newStrategy;
    }


    /**
     * @dev Used to deploy asset to Saving Account. Amount to deposit should be approved to strategy contract
     * @param amount amount of asset deposited
     * @param asset address of the asset deposited
     * @param strategy strategy in which asset has to deposited(ex:- compound,Aave etc)
     **/

    // TODO - change according to the ether 
    // TODO - Number of strategies user can invest in is limited. Make this set specific to user rather than global.

    function deposit(
        uint256 amount,
        address asset,
        address strategy,
        address user
    ) external payable {
        
    }

    /**
     * @dev Used to switch saving strategy of an asset
     * @param currentStrategy initial Strategy of asset
     * @param newStrategy new Strategy of asset
     * @param asset address of the asset
     * @param amount amount of the asset to be switched
     */
    function switchStrategy(
        uint256 currentStrategy,
        uint256 newStrategy,
        address asset,
        uint256 amount
    ) external {
        
    }

    /**
     * @dev Used to withdraw asset from Saving Account
     * @param amount amount of asset withdawn
     * @param asset address of the asset to be withdrawn
     * @param strategy strategy from wherr asset has to withdrawn(ex:- compound,Aave etc)
     */
    function withdraw(
        uint256 amount, // original token amount 
        address asset,  // original token address 
        uint256 strategy
    ) external {
        
    }

    function _withdraw(
        address user,
        uint256 amount, // original token amount 
        address asset,  // original token address 
        uint256 strategy
    ) internal {
        
    }

    function _approveTransfer(address _from, address _to, uint256 _amount, address _asset) internal {
        
    }

    function addCollateralToPool(address _invest, address _pool, uint256 _amount, address _asset) public {
        
    }

    function lendToPool(address _invest, address _pool, uint256 _amount, address _asset) public {
        
    }
}
