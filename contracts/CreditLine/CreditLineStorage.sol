// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

/**
 * @title Credit Line contract with Methods related to credit Line
 * @notice Implements the functions related to Credit Line
 * @author Sublime
 **/

contract CreditLineStorage is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    enum creditLineStatus {NOT_CREATED, REQUESTED, ACTIVE, CLOSED, CANCELLED, LIQUIDATED}

    uint256 public CreditLineCounter;

    // assuming number of days in year is 365 more discussion is needed for this
    uint256 public constant yearInSeconds = 365 days;

    /*struct repayments {
        uint256 lastRepaymentTime;
        uint256 currentDebt;
        uint256 netPrinciple;
        uint256 accrueInterest;
    }*/

    struct CreditLineUsageVars {
        uint256 principal;
        uint256 totalInterestRepaid;
        uint256 lastPrincipalUpdateTime;
        uint256 interestAccruedTillPrincipalUpdate;
        uint256 collateralAmount;
    }

    struct CreditLineVars {
        bool exists;
        address lender;
        address borrower;
        uint256 borrowLimit;
        uint256 idealCollateralRatio;
        uint256 liquidationThreshold;
        uint256 borrowRate;
        address borrowAsset;
        address collateralAsset;
        creditLineStatus currentStatus;
        bool autoLiquidation;
        bool requestByLender;
    }
    mapping(bytes32 => mapping(address => uint256)) collateralShareInStrategy;
    mapping(bytes32 => CreditLineUsageVars) public creditLineUsage;
    mapping(bytes32 => CreditLineVars) public creditLineInfo;
}
