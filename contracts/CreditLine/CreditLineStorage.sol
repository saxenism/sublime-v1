// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


/**
 * @title Credit Line contract with Methods related to credit Line
 * @notice Implements the functions related to Credit Line
 * @author Sublime
 **/

contract CreditLineStorage is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    
    enum creditLineStatus {REQUESTED, ACTIVE, CLOSED, INACTIVE}

    uint256 CreditLineCounter;

    // assuming number of days in year is 356 more discussion is needed for this
    uint256 public constant yearSeconds = 365 days;

    struct repayments {
        uint256 lastPaymentTime;
        uint256 currentDebt;
        uint256 netPrinciple;
        uint256 accrueInterest;
    }

    struct creditLine {
        bool exists;
        address lender;
        address borrower;
        uint256 borrowAmount;
        uint256 collateralRatio;
        uint256 liquidationThreshold;
        uint256 borrowRate;
        uint256 totalnetPrincipal;
        address borrowTokenType;
        address collateralTokenType;
        bool autoLiquidation;
        creditLineStatus currentStatus;
    }

    mapping(bytes32 => repayments) public repaymentsInfo;
    mapping(bytes32 => creditLine) public creditLineInfo;

    address public PriceOracle;
}
