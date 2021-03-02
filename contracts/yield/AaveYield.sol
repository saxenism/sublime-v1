// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/IYield.sol";
import "../interfaces/Invest/IWETHGateway.sol";
import "../interfaces/Invest/AaveLendingPool.sol";
import "../interfaces/Invest/IScaledBalanceToken.sol";
import "../interfaces/Invest/IProtocolDataProvider.sol";

/**
 * @title Yield contract
 * @notice Implements the functions to lock/unlock tokens into Aave protocol
 * @author Sublime
 **/
contract AaveYield is IYield, Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    //Aave related addresses
    address public wethGateway;
    address public protocolDataProvider;
    address public lendingPoolAddressesProvider;

    address payable public savingsAccount;
    uint16 public referralCode;

    modifier onlySavingsAccount {
        require(
            _msgSender() == savingsAccount,
            "Invest: Only savings account can invoke"
        );
        _;
    }

    /**
     * @dev To initialize the contract addresses interacting with this contract
     * @param _protocolDataProvider the address of ProtocolDataProvider
     * @param _lendingPoolAddressesProvider the address of LendingPoolAddressesProvider
     **/
    function initialize(
        address _owner,
        address payable _savingsAccount,
        address _wethGateway,
        address _protocolDataProvider,
        address _lendingPoolAddressesProvider
    ) public initializer {
        __Ownable_init();
        super.transferOwnership(_owner);

        require(
            _savingsAccount != address(0),
            "Invest: SavingsAccount:: zero address"
        );
        require(
            _wethGateway != address(0),
            "Invest: WETHGateway:: zero address"
        );
        require(
            _protocolDataProvider != address(0),
            "Invest: protocolDataProvider:: zero address"
        );
        require(
            _lendingPoolAddressesProvider != address(0),
            "Invest: lendingPoolAddressesProvider:: zero address"
        );

        savingsAccount = _savingsAccount;
        wethGateway = _wethGateway;
        protocolDataProvider = _protocolDataProvider;
        lendingPoolAddressesProvider = _lendingPoolAddressesProvider;
    }

    function updateSavingAccount(address payable _savingsAccount)
        external
        onlyOwner
    {
        require(_savingsAccount != address(0), "Invest: zero address");
        savingsAccount = _savingsAccount;
    }

    function updateAaveAddresses(
        address _wethGateway,
        address _protocolDataProvider,
        address _lendingPoolAddressesProvider
    ) external onlyOwner {
        require(
            _wethGateway != address(0),
            "Invest: WETHGateway:: zero address"
        );
        require(
            _protocolDataProvider != address(0),
            "Invest: protocolDataProvider:: zero address"
        );
        require(
            _lendingPoolAddressesProvider != address(0),
            "Invest: lendingPoolAddressesProvider:: zero address"
        );
        wethGateway = _wethGateway;
        protocolDataProvider = _protocolDataProvider;
        lendingPoolAddressesProvider = _lendingPoolAddressesProvider;
    }

    function updateReferralCode(uint16 _referralCode) external onlyOwner {
        referralCode = _referralCode;
    }

    function emergencyWithdraw(address _asset, address payable _wallet)
        external
        onlyOwner
        returns (uint256 received)
    {
        (address aToken, , ) =
            IProtocolDataProvider(protocolDataProvider)
                .getReserveTokensAddresses(_asset);

        uint256 amount = IERC20(aToken).balanceOf(address(this));

        if (_asset == address(0)) {
            received = _withdrawETH(amount);
            _wallet.transfer(received);
        } else {
            received = _withdrawERC(_asset, amount);
            IERC20(_asset).transfer(_wallet, received);
        }
    }

    /**
     * @dev Used to lock tokens in available protocol
     * @notice Asset Tokens to be locked must be approved to this contract by user
     * @param asset the address of token to invest
     * @param amount the amount of asset
     * @return sharesReceived amount of shares received
     **/
    function lockTokens(
        address user,
        address asset,
        uint256 amount
    )
        public
        payable
        override
        onlySavingsAccount
        returns (uint256 sharesReceived)
    {
        require(amount != 0, "Invest: amount");

        address investedTo;
        if (asset == address(0)) {
            require(msg.value == amount, "Invest: ETH amount");
            (investedTo, sharesReceived) = _depositETH(amount);
        } else {
            IERC20(asset).safeTransferFrom(user, address(this), amount);
            (investedTo, sharesReceived) = _depositERC20(asset, amount);
        }

        emit LockedTokens(user, investedTo, sharesReceived);
    }

    /**
     * @dev Used to unlock tokens from available protocol
     * @param asset the address of underlying token
     * @param amount the amount of asset
     * @return received amount of tokens received
     **/
    function unlockTokens(address asset, uint256 amount)
        public
        override
        onlySavingsAccount
        returns (uint256 received)
    {
        require(amount != 0, "Invest: amount");

        if (asset == address(0)) {
            received = _withdrawETH(amount);
            savingsAccount.transfer(received);
        } else {
            received = _withdrawERC(asset, amount);
            IERC20(asset).transfer(savingsAccount, received);
        }

        emit UnlockedTokens(asset, received);
    }

    /**
     * @dev Used to get amount of underlying tokens for current number of shares
     * @param shares the amount of shares
     * @param asset the address of token locked
     * @return amount amount of underlying tokens
     **/
    function getTokensForShares(uint256 shares, address asset)
        external
        view
        override
        returns (uint256 amount)
    {
        if (shares == 0) return 0;
        (address aToken, , ) =
            IProtocolDataProvider(protocolDataProvider)
                .getReserveTokensAddresses(asset);

        (, , , , , , , uint256 liquidityIndex, , ) =
            IProtocolDataProvider(protocolDataProvider).getReserveData(asset);

        amount = IScaledBalanceToken(aToken)
            .scaledBalanceOf(address(this))
            .mul(liquidityIndex)
            .mul(shares)
            .div(IERC20(aToken).balanceOf(address(this)));
    }

    function _depositETH(uint256 amount)
        internal
        returns (address aToken, uint256 sharesReceived)
    {
        aToken = IWETHGateway(wethGateway).getAWETHAddress();

        uint256 aTokensBefore = IERC20(aToken).balanceOf(address(this));

        //lock collateral
        IWETHGateway(wethGateway).depositETH{value: amount}(
            address(this),
            referralCode
        );

        sharesReceived = IERC20(aToken).balanceOf(address(this)).sub(
            aTokensBefore
        );
    }

    function _depositERC20(address asset, uint256 amount)
        internal
        returns (address aToken, uint256 sharesReceived)
    {
        (aToken, , ) = IProtocolDataProvider(protocolDataProvider)
            .getReserveTokensAddresses(asset);

        uint256 aTokensBefore = IERC20(aToken).balanceOf(address(this));

        address lendingPool =
            ILendingPoolAddressesProvider(lendingPoolAddressesProvider)
                .getLendingPool();

        //approve collateral to vault
        IERC20(asset).approve(lendingPool, amount);

        //lock collateral in vault
        AaveLendingPool(lendingPool).deposit(
            asset,
            amount,
            address(this),
            referralCode
        );

        sharesReceived = IERC20(aToken).balanceOf(address(this)).sub(
            aTokensBefore
        );
    }

    function _withdrawETH(uint256 amount) internal returns (uint256 received) {
        IERC20(IWETHGateway(wethGateway).getAWETHAddress()).approve(
            wethGateway,
            amount
        );

        uint256 ethBalance = address(this).balance;

        //lock collateral
        IWETHGateway(wethGateway).withdrawETH(amount, address(this));

        received = address(this).balance.sub(ethBalance);
    }

    function _withdrawERC(address asset, uint256 amount)
        internal
        returns (uint256 tokensReceived)
    {
        (address aToken, , ) =
            IProtocolDataProvider(protocolDataProvider)
                .getReserveTokensAddresses(asset);

        address lendingPool =
            ILendingPoolAddressesProvider(lendingPoolAddressesProvider)
                .getLendingPool();

        uint256 tokensBefore = IERC20(asset).balanceOf(address(this));

        IERC20(aToken).approve(lendingPool, amount);

        //withdraw collateral from vault
        AaveLendingPool(lendingPool).withdraw(asset, amount, address(this));

        tokensReceived = IERC20(asset).balanceOf(address(this)).sub(
            tokensBefore
        );
    }
}
