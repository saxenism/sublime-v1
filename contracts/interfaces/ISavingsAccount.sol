// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface SavingAccount {
    function deposit(
        uint256 amount,
        address asset,
        address strategy,
        address user
    ) external payable;

    function switchStrategy(
        uint256 currentStrategy,
        uint256 newStrategy,
        address asset,
        uint256 amount
    ) external;

    function withdraw(
        uint256 amount,
        address asset,
        uint256 strategy
    ) external;

    function addCollateralToPool(
        address _invest,
        address _pool,
        uint256 _amount,
        address _asset
    ) external;

    function lendToPool(
        address _invest,
        address _pool,
        uint256 _amount,
        address _asset
    ) external;
}
