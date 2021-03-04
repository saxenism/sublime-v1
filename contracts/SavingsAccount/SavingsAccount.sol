// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/ISavingsAccount.sol";
import "../interfaces/IStrategyRegistry.sol";
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

    //user -> strategy -> token (underlying address) -> amount (shares)
    mapping(address => mapping(address => mapping(address => uint256)))
        public userLockedBalance;

    //user -> token (underlying address) -> amount (shares)
    mapping(address => mapping(address => uint256)) public savingsAccountInfo;

    //user => asset => to => amount
    mapping(address => mapping(address => mapping(address => uint256)))
        public allowance;

    // TODO : Track strategies per user and limit no of strategies to 5

    /**
     * @dev initialize the contract
     * @param _owner address of the owner of the savings account contract
     * @param _strategyRegistry address of the strategy registry
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

    // TODO - Number of strategies user can invest in is limited. Make this set specific to user rather than global.

    /**
     * @dev This function is used to deposit asset into savings account.
     * @dev It also helps in investing the asset.
     * @notice The asset should be approved to desired strategy beforehand
     * @param amount amount of asset deposited
     * @param asset address of asset deposited
     * @param strategy address of strategy to invest in
     * @param user address of user depositing into savings account
     */
    function deposit(
        uint256 amount,
        address asset,
        address strategy,
        address user
    ) external payable override returns (uint256 sharesReceived) {
        require(
            amount != 0,
            "SavingsAccount::deposit Amount must be greater than zero"
        );

        if (strategy != address(0)) {
            sharesReceived = _depositToYield(amount, asset, strategy, user);
        } else {
            sharesReceived = amount;
            if (asset != address(0)) {
                IERC20(asset).transferFrom(user, address(this), amount);
            }
        }

        userLockedBalance[user][asset][strategy] = userLockedBalance[user][
            asset
        ][strategy]
            .add(sharesReceived);

        savingsAccountInfo[user][asset] = savingsAccountInfo[user][asset].add(
            sharesReceived
        );

        emit Deposited(user, amount, asset);
    }

    function _depositToYield(
        uint256 amount,
        address asset,
        address strategy,
        address user
    ) internal returns (uint256 sharesReceived) {
        require(
            IStrategyRegistry(strategyRegistry).registry(strategy),
            "SavingsAccount::deposit strategy do not exist"
        );

        if (asset == address(0)) {
            sharesReceived = IYield(strategy).lockTokens{value: amount}(
                user,
                asset,
                amount
            );
        } else {
            sharesReceived = IYield(strategy).lockTokens(user, asset, amount);
        }
    }

    /**
     * @dev Used to switch saving strategy of an asset
     * @param currentStrategy initial strategy of asset
     * @param newStrategy new strategy to invest
     * @param asset address of the asset
     * @param amount amount of **liquidity shares** to be reinvested
     */
    function switchStrategy(
        address currentStrategy,
        address newStrategy,
        address asset,
        uint256 amount
    ) external override {
        require(
            amount != 0,
            "SavingsAccount::switchStrategy Amount must be greater than zero"
        );

        require(
            userLockedBalance[msg.sender][asset][currentStrategy] >= amount,
            "SavingsAccount::switchStrategy Insufficient balance"
        );

        userLockedBalance[msg.sender][asset][
            currentStrategy
        ] = userLockedBalance[msg.sender][asset][currentStrategy].sub(amount);

        uint256 tokensReceived = amount;
        if (currentStrategy != address(0)) {
            tokensReceived = IYield(currentStrategy).unlockTokens(
                asset,
                amount
            );
        }

        uint256 sharesReceived = tokensReceived;
        if (newStrategy != address(0)) {
            IERC20(asset).approve(newStrategy, tokensReceived);
            sharesReceived = _depositToYield(
                tokensReceived,
                asset,
                newStrategy,
                address(this)
            );
        }

        userLockedBalance[msg.sender][asset][newStrategy] = userLockedBalance[
            msg.sender
        ][asset][newStrategy]
            .add(sharesReceived);

        savingsAccountInfo[msg.sender][asset] = savingsAccountInfo[msg.sender][
            asset
        ]
            .sub(amount)
            .add(sharesReceived);

        // emit StrategySwitched(msg.sender, currentStrategy, newStrategy);
    }

    /**
     * @dev Used to withdraw asset from Saving Account
     * @param amount amount of liquidity shares to withdraw
     * @param asset address of the asset to be withdrawn
     * @param strategy strategy from where asset has to withdrawn(ex:- compound,Aave etc)
     * @param withdrawShares boolean indicating to withdraw in liquidity share or underlying token
     */
    function withdraw(
        uint256 amount,
        address asset,
        address strategy,
        bool withdrawShares
    ) external override {
        require(
            userLockedBalance[msg.sender][asset][strategy] >= amount,
            "SavingsAccount::withdraw Insufficient amount"
        );

        userLockedBalance[msg.sender][asset][strategy] = userLockedBalance[
            msg.sender
        ][asset][strategy]
            .sub(amount);

        savingsAccountInfo[msg.sender][asset] = savingsAccountInfo[msg.sender][
            asset
        ]
            .sub(amount);

        uint256 amountReceived = amount;

        if (!withdrawShares || strategy != address(0)) {
            amountReceived = _withdraw(msg.sender, amount, asset, strategy);
        }

        address token = asset;
        if (withdrawShares) token = IYield(strategy).liquidityToken(asset);

        if (token == address(0)) {
            msg.sender.transfer(amountReceived);
        } else {
            IERC20(token).safeTransfer(msg.sender, amountReceived);
        }
    }

    function _withdraw(
        address user,
        uint256 amount,
        address asset,
        address strategy
    ) internal returns (uint256 amountReceived) {
        require(
            amount != 0,
            "SavingsAccount::withdraw Amount must be greater than zero"
        );

        require(
            userLockedBalance[user][asset][strategy] >= amount,
            "SavingsAccount::withdraw insufficient balance"
        );

        amountReceived = IYield(strategy).unlockTokens(asset, amount);

        emit Withdrawn(user, amountReceived, asset, strategy);
    }

    function withdrawAll(
        address _to,
        uint256 _amount,
        address _asset
    ) external override returns (uint256 tokenReceived) {
        uint256 assetTotalBalance = savingsAccountInfo[msg.sender][_asset];
        require(
            _amount <= assetTotalBalance,
            "SavingsAccount::withdrawAll insufficient funds"
        );

        // Withdraw tokens
        address[] memory _strategyList =
            IStrategyRegistry(strategyRegistry).getStrategies();

        uint256 _amountLeft = _amount;
        for (uint256 index = 0; index < _strategyList.length; index++) {
            uint256 _balanceInStrategy =
                userLockedBalance[msg.sender][_asset][_strategyList[index]];

            uint256 _toWithdraw;
            if (_amountLeft <= _balanceInStrategy) {
                _toWithdraw = _amountLeft;
            } else {
                _toWithdraw = _balanceInStrategy;
            }

            _amountLeft = _amountLeft.sub(_toWithdraw);
            tokenReceived = tokenReceived.add(
                _withdraw(msg.sender, _toWithdraw, _asset, _strategyList[index])
            );

            if (_amountLeft == 0) {
                break;
            }
        }

        // approve transfer
        IERC20(_asset).safeApprove(_to, _amount);
    }

    function approve(
        address token,
        address to,
        uint256 amount
    ) external override {
        require(amount != 0, "SavingsAccount::approve zero amount");
        allowance[msg.sender][token][to] = allowance[msg.sender][token][to].add(
            amount
        );

        //emit Approved(token, msg.sender, to , amount);
    }

    function transfer(
        address token,
        address to,
        address investedTo,
        uint256 amount
    ) external override returns (uint256) {
        require(amount != 0, "SavingsAccount::transfer zero amount");
        require(
            savingsAccountInfo[msg.sender][token] >= amount,
            "SavingsAccount::transfer insufficient funds"
        );

        //reduce msg.sender balance
        savingsAccountInfo[msg.sender][token] = savingsAccountInfo[msg.sender][
            token
        ]
            .sub(amount);

        userLockedBalance[msg.sender][token][investedTo] = userLockedBalance[
            msg.sender
        ][token][investedTo]
            .add(amount);

        //update receiver's balance
        savingsAccountInfo[to][token] = savingsAccountInfo[to][token].add(
            amount
        );

        userLockedBalance[to][token][investedTo] = userLockedBalance[to][token][
            investedTo
        ]
            .add(amount);

        //not sure
        return amount;

        // emit Transfer(token, msg.sender, to, amount);
    }

    function transferFrom(
        address token,
        address from,
        address to,
        address investedTo,
        uint256 amount
    ) external override returns (uint256) {
        require(amount != 0, "SavingsAccount::transferFrom zero amount");
        require(
            allowance[from][token][msg.sender] >= amount,
            "SavingsAccount::transferFrom insufficient allowance"
        );

        require(
            savingsAccountInfo[from][token] >= amount,
            "SavingsAccount::transferFrom insufficient funds"
        );

        //update allowance
        allowance[from][token][msg.sender] = allowance[from][token][msg.sender]
            .sub(amount);

        //reduce sender's balance
        savingsAccountInfo[from][token] = savingsAccountInfo[from][token].sub(
            amount
        );

        userLockedBalance[from][token][investedTo] = userLockedBalance[from][
            token
        ][investedTo]
            .add(amount);

        //update receiver's balance
        savingsAccountInfo[to][token] = savingsAccountInfo[to][token].add(
            amount
        );

        userLockedBalance[to][token][investedTo] = userLockedBalance[to][token][
            investedTo
        ]
            .add(amount);

        //not sure
        return amount;

        // emit Transfer(token, from, to, amount);
    }
}
