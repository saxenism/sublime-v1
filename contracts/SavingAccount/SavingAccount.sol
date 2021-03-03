// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/ISavingsAccount.sol";
import "../interfaces/IYield.sol";
import "../interfaces/IPool.sol";

/**
 * @title Savings account contract with Methods related to savings account
 * @notice Implements the functions related to savings account
 * @author Sublime
 **/
contract SavingsAccount is ISavingsAccount, Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public strategyRegistry;
    // TODO: this can probably be removed
    mapping(address => mapping(address => uint256)) public savingsAccountInfo;

    mapping(address => mapping(address => mapping(address => uint256)))
        public userLockedBalance;

    // TODO : Track strategies per user and limit no of strategies to 5

    /**
     * @dev emits when user deposit asset to Saving Account
     * @param user address of the user who deposited into saving account
     * @param amount amount of the asset deposited
     * @param asset address of the asset deposited
     **/
    event Deposited(address user, uint256 amount, address asset);

    /**
     * @dev emits when user withdraw asset from Saving Account
     * @param user address of the user who withdrawn from saving account
     * @param amount amount of the asset withdrawn
     * @param asset address of the asset withdrawn
     * @param strategy address of the asset withdrawn
     **/
    event Withdrawn(
        address user,
        uint256 amount,
        address asset,
        uint256 strategy
    );

    /**
     * @dev initialize the contract
     * @param _owner address of the owner of the savings account contract
     **/
    function initialize(address _owner, address _strategyRegistry)
        public
        initializer
    {
        require(
            _strategyRegistry != address(0),
            "SavingsAccount::initialize zero address"
        );
        __Ownable_init();
        super.transferOwnership(_owner);

        strategyRegistry = _strategyRegistry;
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
        require(amount != 0, "Amount must be greater than zero");
        savingsAccountInfo[user][asset] = savingsAccountInfo[user][asset].add(
            amount
        );

        // uint256 tokens = IYield(_invest).getTokensForShares(strategy,amount,asset);
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(strategy, amount);

        uint256 tokens = IYield(strategy).lockTokens(asset, amount);
        userLockedBalance[user][asset][strategy] = (
            userLockedBalance[user][asset][strategy]
        )
            .add(tokens);
        emit Deposited(user, amount, asset);
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
        require(amount > 0, "amount must be greater than zero");

        uint256 currentStrategyTokens =
            IYield(currentStrategy).getTokensForShares(amount, asset);
        // TODO - How will this happen ?
        require(
            userLockedBalance[msg.sender][asset][currentStrategy] >
                currentStrategyTokens,
            "insufficient balance"
        );
        IYield(currentStrategy).unlockTokens(asset, currentStrategyTokens);
        userLockedBalance[msg.sender][asset][currentStrategy] = (
            userLockedBalance[msg.sender][asset][currentStrategy]
        )
            .sub(currentStrategyTokens);

        uint256 newStrategyTokens =
            IYield(newStrategy).getTokensForShares(amount, asset);
        IERC20(asset).approve(newStrategy, amount);
        IYield(newStrategy).lockTokens(asset, newStrategyTokens);
        userLockedBalance[msg.sender][asset][newStrategy] = (
            userLockedBalance[msg.sender][asset][newStrategy]
        )
            .add(newStrategyTokens);
    }

    /**
     * @dev Used to withdraw asset from Saving Account
     * @param amount amount of asset withdawn
     * @param asset address of the asset to be withdrawn
     * @param strategy strategy from wherr asset has to withdrawn(ex:- compound,Aave etc)
     */
    function withdraw(
        uint256 amount, // original token amount
        address asset, // original token address
        uint256 strategy
    ) external {
        _withdraw(msg.sender, amount, asset, strategy);
        if (asset == address(0)) {
            msg.sender.transfer(amount);
        } else {
            SafeERC20(asset).transfer(msg.sender, amount);
        }
    }

    function _withdraw(
        address user,
        uint256 amount, // original token amount
        address asset, // original token address
        uint256 strategy
    ) internal {
        require(amount > 0, "Amount must be greater than zero");

        // uint256 tokens = IYield(_invest).getTokensForShares( strategy,amount, asset);
        require(
            userLockedBalance[user][asset][strategy] > amount,
            "insufficient balance"
        );
        uint256 token = IYield(strategy).unlockTokens(asset, amount);

        userLockedBalance[msg.sender][asset][strategy] = (
            userLockedBalance[msg.sender][asset][strategy]
        )
            .sub(amount);
        savingsAccountInfo[msg.sender][asset] = savingsAccountInfo[msg.sender][
            asset
        ]
            .sub(amount);

        emit Withdrawn(user, amount, asset, strategy);
    }

    function _approveTransfer(
        address _from,
        address _to,
        uint256 _amount,
        address _asset
    ) internal {
        uint256 assetTotalBalance = savingsAccountInfo[_from][_asset];
        require(_amount <= assetTotalBalance, "");
        // Withdraw tokens
        address[] memory _strategyList = strategies;
        uint256 _amountLeft = _amount;
        for (uint256 i = 0; i < _strategyList.length; i++) {
            address _strategy = _strategyList[i];
            uint256 _toWithdraw;
            uint256 _balanceInStrategy =
                userLockedBalance[_from][_asset][_strategy];
            if (_amountLeft <= _balanceInStrategy) {
                _toWithdraw = _amountLeft;
            } else {
                _toWithdraw = _balanceInStrategy;
            }
            _amountLeft = _amountLeft.sub(_toWithdraw);
            _withdraw(_from, _toWithdraw, _asset, _strategy);
            if (_amountLeft == 0) {
                break;
            }
        }
        // approve transfer
        SafeERC20(_asset).approve(_to, _amount);
    }

    function addCollateralToPool(
        address _invest,
        address _pool,
        uint256 _amount,
        address _asset
    ) public {
        _approveTransfer(msg.sender, _invest, _amount, _asset);
        IPool(_pool).deposit(msg.sender, _amount);
    }

    function lendToPool(
        address _invest,
        address _pool,
        uint256 _amount,
        address _asset
    ) public {
        _approveTransfer(msg.sender, _invest, _amount, _asset);
        IPool(_pool).lend(msg.sender, _amount);
    }
}
