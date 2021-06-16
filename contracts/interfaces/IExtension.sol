// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface IExtension {
    function initializePoolExtension(uint256 _repaymentInterval) external;

    function closePoolExtension() external;
}
