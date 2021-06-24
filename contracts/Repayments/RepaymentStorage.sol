// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IPoolFactory.sol";

contract RepaymentStorage is OwnableUpgradeable {
    address internal _owner;
    IPoolFactory poolFactory;
    address savingsAccount;

    enum LoanStatus {
        COLLECTION, //denotes collection period
        ACTIVE, // denotes the active loan
        CLOSED, // Loan is repaid and closed
        CANCELLED, // Cancelled by borrower
        DEFAULTED, // Repaymennt defaulted by  borrower
        TERMINATED // Pool terminated by admin
    }

    uint256 votingPassRatio;
    uint256 gracePenaltyRate;
    uint256 gracePeriodFraction; // fraction of the repayment interval
    uint256 public constant yearInSeconds = 365 days;

    struct RepaymentDetails {
        uint256 numberOfTotalRepayments; // using it to check if RepaymentDetails Exists as repayment Interval!=0 in any case
        uint256 gracePenaltyRate;
        uint256 gracePeriodFraction;
        uint256 totalRepaidAmount;
        uint256 loanDuration;
        uint256 repaymentInterval;
        uint256 repaymentPeriodCovered;
        uint256 repaymentOverdue;
        bool isLoanExtensionActive;
        uint256 borrowRate;
        uint256 repaymentDetails;
        uint256 loanStartTime;
        address repayAsset;
        address savingsAccount;

        uint256 loanDurationCovered;
    }

    mapping(address => RepaymentDetails) repaymentDetails;
}
