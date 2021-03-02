// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface IBorrower {
    function isBorrower(address _borrower) external view returns(bool);
}