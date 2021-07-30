// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '../interfaces/IPoolFactory.sol';

/**
 * @title Repayment Storage contract
 * @notice Implements the storage structures that will be used in the Repayments contract
 * @author Sublime
 */
contract RepaymentStorage is OwnableUpgradeable {
    address internal _owner;

    /// @notice instance of the IPoolFactory interface
    IPoolFactory poolFactory;

    address savingsAccount;

    /// @notice An enumerated list containing the various possible loan statuses for increasing code-readability
    /// @param COLLECTION
    /// @param ACTIVE denotes the active loan
    /// @param CLOSED Loan is repaid and closed
    /// @param CANCELLED Cancelled by borrower
    /// @param DEFAULTED Repaymennt defaulted by  borrower
    /// @param TERMINATED // Pool terminated by admin
    enum LoanStatus {
        COLLECTION, //denotes collection period
        ACTIVE, // denotes the active loan
        CLOSED, // Loan is repaid and closed
        CANCELLED, // Cancelled by borrower
        DEFAULTED, // Repaymennt defaulted by  borrower
        TERMINATED // Pool terminated by admin
    }

    /// @notice ratio of votes from liquidators required to reach a decision by concensus
    uint256 votingPassRatio;

    /// @notice penalty rate to be imposed in the grace period
    uint256 gracePenaltyRate;
    
    /// @notice fraction of the repayment interval
    uint256 gracePeriodFraction; 
    
    /// @notice uint expressing a year in number of seconds
    uint256 constant yearInSeconds = 365 days;

    /// @notice a struct consisting of the variables associated with a Repayment object
    /// @param totalRepaidAmount total amount repaid by the borrower till now
    /// @param repaymentPeriodCovered number of repayment periods covered till now
    /// @param isLoanExtensionActive has an extension on the repayment date of the loan been approved?
    /// @param loanDurationCovered time covered considering the loan start time
    /// @param nextDuePeriod timestamp of the next period when interest will be due by the borrower
    /// @param nInstalmentsFullyPaid number of instalments fully paid
    /// @param loanExtensionPeriod period for which the extension was granted, ie, if loanExtensionPeriod is 7 * 10**30, 7th instalment can be repaid by 8th instalment deadline
    struct RepaymentVars {
        uint256 totalRepaidAmount;
        // uint256 repaymentPeriodCovered; // deprecated in favour of getInstalmentsCompleted() in Repayments.sol
        bool isLoanExtensionActive;
        uint256 loanDurationCovered;
        uint256 nextDuePeriod;
        uint256 nInstalmentsFullyPaid;
        uint256 loanExtensionPeriod; 
    }

    /// @notice a struct consisting of the constants associated with a Repayment object
    /// @param numberOfTotalRepayments using it to check if RepaymentDetails Exists as repayment Interval!=0 in any case
    /// @param gracePenaltyRate rate at which a penalty is imposed on the borrower in the grace period
    /// @param gracePeriodFraction a fraction of the repayment period decided as the grace period
    /// @param loadDuration duration of the loan lent to the borrower
    /// @param repaymentInterval intervals after which the borrower will have overdues
    /// @param borrowRate interest rate at which the loan was lent to the borrower
    /// @param loanStartTime time at which the loan officialy started/was lent
    /// @param repayAsset address of the asset (mostly an ERC 20 token) that will be used to repay the loan
    /// @param savingsAccount address of the saving account
    struct RepaymentConstants {
        uint256 numberOfTotalRepayments; 
        uint256 gracePenaltyRate;
        uint256 gracePeriodFraction;
        uint256 loanDuration;
        uint256 repaymentInterval;
        uint256 borrowRate;
        //uint256 repaymentDetails;
        uint256 loanStartTime;
        address repayAsset;
        address savingsAccount;
    }

    /// @notice mapping to attach a borrower address to their own Repayment variables
    mapping(address => RepaymentVars) public repaymentVars;
    /// @notice mapping to attach a borrower address to their own Repayment constants
    mapping(address => RepaymentConstants) public repaymentConstants;
}
