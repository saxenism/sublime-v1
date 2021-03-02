// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./CreditLineStorage.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @title Credit Line contract with Methods related to credit Line
 * @notice Implements the functions related to Credit Line
 * @author Sublime
 **/



contract CreditLine is CreditLineStorage {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    /**
     * @dev checks if Credit Line exists
     * @param creditLineHash credit hash
     **/
    modifier ifcreditLineExists(bytes32 creditLineHash) {
        require(
            creditLineInfo[creditLineHash].exists == true,
            "CreditLine Doesn't exists"
        );
        _;
    }

    /**
     * @dev checks if called by credit Line Borrower
     * @param creditLineHash creditLine Hash
     **/
    modifier onlyCreditLineBorrower(bytes32 creditLineHash) {
        require(
            creditLineInfo[creditLineHash].borrower == msg.sender,
            "only Credit Line Borrower can access"
        );
        _;
    }

    /**
     * @dev checks if called by credit Line Lender
     * @param creditLineHash creditLine Hash
     **/
    modifier onlyCreditLineLender(bytes32 creditLineHash) {
        require(
            creditLineInfo[creditLineHash].lender == msg.sender,
            "only Credit Line Lender can access"
        );
        _;
    }


    /**
     * @dev emits when borrower request for a credit Line
     * @param creditLineHash the credit Line Hash
     **/
    event creditLineRequested(bytes32 creditLineHash);


    function initialize() public initializer {
        __Ownable_init();
    }


    /**
     * @dev Used to Calculate Interest Per second on given principle and Interest rate
     * @param principle principle Amount for which interest has to be calculated.
     * @param borrowRate It is the Interest Rate at which Credit Line is approved
    * @return uint256 interest per second for the given parameters
    */
    function calculateInterestPerSecond(uint256 principle, uint256 borrowRate)
        public
        view
        returns (uint256)
    {
        
    }


    /**
     * @dev Used to Calculate Accrue Interest uptill now which has to be paid
     * @param creditLineHash creditLine Hash of the CreditLine for which Accrue Interest has to be calculated
     * @return uint256 interest Accrued over current borrowed amount
    */

    function calculateAccrueInterest(bytes32 creditLineHash)
        public
        view
        ifcreditLineExists(creditLineHash)
        returns (uint256)
    {
        
    }

    /**
     * @dev Used to Calculate Current Debt for a Borrower
     * @param creditLineHash creditLine Hash of the CreditLine for which Current Debt has to be calculated
     * @return uint256 current debt over user 
    */
    function calculateCurrentDebt(bytes32 creditLineHash)
        public
        ifcreditLineExists(creditLineHash)
        returns (uint256)
    {
        
    }


    // /**
    //  * @dev Used to set Initial Values for a creditLine whenever a CreditLine is Created
    //  * @param creditLineHash creditLine Hash of the CreditLine 
    // */
    // function setRepayments(bytes32 creditLineHash) internal {

    //     repaymentsInfo[creditLineHash] = _repaymentTemp;
    // }


    /**
     * @dev used to request a credit line by a borrower
     * @param _lender lender from whom creditLine is requested
     * @param _borrowAmount maximum borrow amount in a credit line
     * @param _liquidationThreshold threshold for liquidation 
     * @param _borrowRate Interest Rate at which credit Line is requested
    */
    function requestCreditLine(
        address _lender,
        uint256 _borrowAmount,
        uint256 _liquidationThreshold,
        uint256 _borrowRate,
        bool _autoLiquidation
    ) public returns (bytes32) {

        

    }


    /**
     * @dev used to Accept a credit line by a specified lender
     * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    */
    function acceptCreditLine(bytes32 creditLineHash)
        external
        ifcreditLineExists(creditLineHash)
        onlyCreditLineLender(creditLineHash)
    {
        
    }


    //TODO :- Make the function to accept ether as well
    /**
     * @dev used to withdraw assest from credit line 
     * @param amount amount which borrower wants to withdraw from credit line
     * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    */
    function useCreditLine(uint256 amount, bytes32 creditLineHash)
        external
        ifcreditLineExists(creditLineHash)
        onlyCreditLineBorrower(creditLineHash)
    {   

    }


    //TODO:- Make the function to accept ether as well 
    /**
     * @dev used to repay assest to credit line 
     * @param repayAmount amount which borrower wants to repay to credit line
     * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    */
    function repayCreditLine(uint256 repayAmount, bytes32 creditLineHash, address token)
        external
        ifcreditLineExists(creditLineHash)
        onlyCreditLineBorrower(creditLineHash)
    {   

        
    }


    /**
     * @dev used to close credit line once by borrower or lender  
     * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    */
    function closeCreditLine(bytes32 creditLineHash)
        external
        ifcreditLineExists(creditLineHash)
    {
        
    }



    function calculateCurrentCollateralRatio(bytes32 creditLineHash) public ifcreditLineExists(creditLineHash) returns(uint256) {
        
    }

    function liquidation(bytes32 creditLineHash) external ifcreditLineExists(creditLineHash) {


    }






    // Think about threshHold liquidation 
    // only one type of token is accepted check for that
    // collateral ratio has to calculated initially
    // current debt is more than borrow amount
}
