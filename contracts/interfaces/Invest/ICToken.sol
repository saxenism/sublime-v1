// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

interface ICToken {
    function underlying() external view returns (address);

    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function liquidateBorrow(
        address borrower,
        uint256 amount,
        address collateral
    ) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    function balanceOfUnderlying(address account) external returns (uint256);
}
