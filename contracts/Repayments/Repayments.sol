// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";


import "./RepaymentStorage.sol";

contract Repayments is RepaymentStorage {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    modifier isPoolInitialized() {
        require(
             repaymentDetails[msg.sender].numberOfTotalRepayments !=0,
            "Pool is not Initiliazed"
        );
        _;
    }

    function initialize(address poolImpl, address lenderImpl)
        public
        initializer
    {
        __Ownable_init();
    }

    function initializeRepaymentVars(
        uint256 numberOfTotalRepayments,
        uint256 votingExtensionlength,
        uint256 gracepenaltyRate,
        uint256 gracePeriodInterval,
        uint256 loanDuration
    ) external {


    }


    function calculateRepayAmount(
        uint256 borrowRate,
        uint256 activePrincipal,
        uint256 loanStartTime,
        uint256 repaymentInterval
        ) public view returns(uint256) {

        uint256 memory yearInSeconds = 365 days;
        // assuming repaymentInterval is in seconds
        uint256 memory currentPeriod = (block.timestamp.sub(loanStartTime)).div(repaymentInterval);

        uint256 memory interestPerSecond = activePrincipal
                                           .mul(borrowRate)
                                           .div(yearInSeconds);

        uint256 memory periodEndTime = loanStartTime.add((currentPeriod.add(1)).mul(repaymentInterval));

        uint256 memory interestDueTillPeriodEnd = interestPerSecond
                                                  .mul((periodEndTime)
                                                    .sub(repaymentDetails[poolID].repaymentPeriodCovered));
        return interestDueTillPeriodEnd;
    }

    event InterestRepaid(address poolID, uint256 repayAmount); // Made during current period interest repayment
    event MissedRepaymentRepaid(address poolID); // Previous period's interest is repaid fully
    event PartialExtensionRepaymentMade(address poolID); // Previous period's interest is repaid partially

    function repayAmount(
        address poolID,
        uint256 repayAmount,
        uint256 activePrincipal,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        bool isLoanExtensionActive
    ) public isPoolInitialized {
        //repayAmount() in Pool.sol is already performing pool status check - confirm this

        // assuming repaymentInterval is in seconds

        uint256 memory interestPerSecond = activePrincipal
                                           .mul(borrowRate)
                                           .div(yearInSeconds);

        uint256 memory interestDueTillPeriodEnd = calculateRepayAmount(borrowRate, 
                                                                        activePrincipal, 
                                                                        loanStartTime, 
                                                                        repaymentInterval);


        if (isLoanExtensionActive == false) {
            // might consider transferring interestDueTillPeriodEnd and refunding the rest
            require(repayAmount < interestDueTillPeriodEnd,
                    "Repayments - repayAmount is greater than interest due this period.");
            
            // TODO add transfer

            uint256 memory periodCovered = repayAmount
                                            .div(interestPerSecond);

            repaymentDetails[poolID].repaymentPeriodCovered = repaymentDetails[poolID].repaymentPeriodCovered
                                                              .add(periodCovered);

            emit InterestRepaid(poolID, repayAmount);

        }
        else {
            if (repayAmount >= repaymentDetails[poolID].repaymentOverdue) {
                repaymentDetails[poolID].repaymentOverdue = 0;
                isLoanExtensionActive = false;
                repayAmount = repayAmount.sub(repaymentDetails[poolID].repaymentOverdue);
                emit MissedRepaymentRepaid(poolID);

                // might consider transferring interestDueTillPeriodEnd and refunding the rest
                require(repayAmount < interestDueTillPeriodEnd,
                        "Repayments - repayAmount is greater than interest due this period.");

                //TODO make token transfer
                uint256 memory periodCovered = repayAmount
                                                .div(interestPerSecond);

                repaymentDetails[poolID].repaymentPeriodCovered = repaymentDetails[poolID].repaymentPeriodCovered
                                                                  .add(periodCovered);
                emit InterestRepaid(poolID, repayAmount);
            }

            else {

                //TODO make token transfer
                repaymentDetails[poolID].repaymentOverdue = repaymentDetails[poolID].repaymentOverdue
                                                            .sub(repayAmount);
                repayAmount = 0;

                emit PartialExtensionRepaymentMade(poolID);
            }
        }

        // returning the status of whether previous interval's interest has been repaid or not
        return isLoanExtensionActive;

    }

    // function TotalDueamountLeft() public view{
    //     uint256 intervalsLeft = totalNumberOfRepayments-calculateCurrentPeriod();
    //     return(intervalLeft.mul(amountPerPeriod()));
    // }

    /*function requestExtension(uint256 extensionVoteEndTime)
        external isPoolInitialized
        returns (uint256)
    {
        
    }*/


    //event LoanExtensionRequest(address poolID);

    /*function requestExtension(address poolID)
        external isPoolInitialized
    {
        require(repaymentDetails[poolID].extensionsGranted > extensionVoteEndTime,
                "Borrower : Extension period has ended.");

        repaymentDetails[poolID].extensionRequested = true;

        emit LoanExtensionRequest(poolID);
    }*/


    /*unction voteOnExtension(address poolID,
                             address voter,
                             uint256 votingPower,
                             uint256 extensionAcceptanceThreshold)
        external 
        isPoolInitialized 
        returns (uint256, uint256) {
        
        require()

    }

    function resultOfVoting(
        uint256 totalExtensionSupport,
        uint256 extensionVoteEndTime,
        uint256 totalSupply,
        uint256 nextDuePeriod
    ) external isPoolInitialized returns (uint256) {
        
    }*/
}
