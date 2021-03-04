// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface ISavingsAccount {
    function deposit(
        uint256 amount,
        address asset,
        address strategy,
        address user
    ) external payable returns (uint256);

    function switchStrategy(
        uint256 currentStrategy,
        uint256 newStrategy,
        address asset,
        uint256 amount
    ) external;

    function withdraw(
        uint256 amount,
        address asset,
        uint256 strategy,
        bool withdrawShares,
        address investedTo
    ) external;

    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount,
        address investedTo
    ) external returns (uint256);

    function transfer(
        address token,
        address to,
        uint256 amount
    ) external returns (uint256);

    function approve(
        address token,
        address to,
        uint256 amount
    ) external;
}
