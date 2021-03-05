// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

interface IPool {


    function depositCollateral(uint256 _amount, bool _isDirect) external payable;

    function addCollateralInMarginCall(
        address _lender,
        uint256 _amount,
        bool _isDirect
    ) external payable;

    function withdrawBorrowedAmount() external;
}
