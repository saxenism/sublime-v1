// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface ISavingsAccount {
    /**
     * @dev emits when user deposit asset to Saving Account
     * @param user address of the user who deposited into saving account
     * @param amount amount of the asset deposited
     * @param asset address of the asset deposited
     * @param strategy address of the strategy
     **/
    event Deposited(
        address user,
        uint256 amount,
        address asset,
        address strategy
    );

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
        address strategy
    );

    /**
     * @dev emits when user withdraw all asset from Saving Account
     * @param user address of the user who withdrawn from saving account
     * @param amount amount of the asset withdrawn
     * @param asset address of the asset withdrawn
     **/
    event WithdrawnAll(address user, uint256 amount, address asset);

    /**
     * @dev emits when user switches the strategy to invest asset
     * @param user address of the user who withdrawn from saving account
     * @param oldStrategy address of the old strategy
     * @param newStrategy address of the new strategy
     **/
    event StrategySwitched(
        address user,
        address oldStrategy,
        address newStrategy
    );

    /**
     * @dev emits when assets are transferred from one address to other
     * @param asset address of the asset trasferred
     * @param strategy address of the strategy to which asset is invested
     * @param from address of the user tokens are transferred from
     * @param to address of the user tokens are transferred to
     * @param amount amount of the asset transferred
     **/
    event Transfer(
        address asset,
        address strategy,
        address from,
        address to,
        uint256 amount
    );

    /**
     * @dev emits when user approves their savings account tokens to someone
     * @param asset address of the asset approved
     * @param from address of the user approving their token
     * @param to address of the user to which tokens are approved
     * @param amount amount of the asset approved
     **/
    event Approved(address asset, address from, address to, uint256 amount);

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
    ) external payable returns (uint256 sharesReceived);

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
    ) external;

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
    ) external;

    function withdrawAll(address _asset)
        external
        returns (uint256 tokenReceived);

    function approve(
        address token,
        address to,
        uint256 amount
    ) external;

    function transfer(
        address token,
        address to,
        address investedTo,
        uint256 amount
    ) external returns (uint256);

    function transferFrom(
        address token,
        address from,
        address to,
        address investedTo,
        uint256 amount
    ) external returns (uint256);
}
