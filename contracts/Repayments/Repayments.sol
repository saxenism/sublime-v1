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

    modifier onlyValidPool {
        require(poolFactory.registry(msg.sender), "Repayments::onlyValidPool - Invalid Pool");
        _;
    }

    function initialize(address _poolFactory, uint256 _votingExtensionlength, uint256 _votingPassRatio)
        public
        initializer
    {
        // _votingExtensionlength - should enforce conditions with repaymentInterval
        __Ownable_init();
        poolFactory = IPoolFactory(_poolFactory);
        votingExtensionlength = _votingExtensionlength;
        votingPassRatio = _votingPassRatio;
    }

    function initializeRepayment(
        uint256 numberOfTotalRepayments,
        uint256 repaymentInterval
    ) external onlyValidPool {
        repaymentDetails[msg.sender].gracePenaltyRate = gracePenaltyRate;
        repaymentDetails[msg.sender].gracePeriodFraction = gracePeriodFraction;
        repaymentDetails[msg.sender].numberOfTotalRepayments = numberOfTotalRepayments;
        repaymentDetails[msg.sender].loanDuration = repaymentInterval.mul(numberOfTotalRepayments);
    }


    function calculateRepayAmount(
        address poolID,
        uint256 borrowRate,
        uint256 activePrincipal,
        uint256 loanStartTime,
        uint256 repaymentInterval
        ) public view returns(uint256) {

        uint256 yearInSeconds = 365 days;
        // assuming repaymentInterval is in seconds
        uint256 currentPeriod = (block.timestamp.sub(loanStartTime)).div(repaymentInterval);

        uint256 interestPerSecond = activePrincipal
                                           .mul(borrowRate)
                                           .div(yearInSeconds);

        uint256 periodEndTime = loanStartTime.add((currentPeriod.add(1)).mul(repaymentInterval));

        uint256 interestDueTillPeriodEnd = interestPerSecond
                                                  .mul((periodEndTime)
                                                    .sub(repaymentDetails[poolID].repaymentPeriodCovered));
        return interestDueTillPeriodEnd;
    }

    event InterestRepaid(address poolID, uint256 repayAmount); // Made during current period interest repayment
    event MissedRepaymentRepaid(address poolID); // Previous period's interest is repaid fully
    event PartialExtensionRepaymentMade(address poolID); // Previous period's interest is repaid partially

    function repayAmount(
        address poolID,
        uint256 amount,
        uint256 activePrincipal,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        bool isLoanExtensionActive
    ) public isPoolInitialized returns (bool) {
        //repayAmount() in Pool.sol is already performing pool status check - confirm this

        // assuming repaymentInterval is in seconds

        uint256 yearInSeconds = 365 days;
        uint256 interestPerSecond = activePrincipal
                                           .mul(borrowRate)
                                           .div(yearInSeconds);

        uint256 interestDueTillPeriodEnd = calculateRepayAmount(poolID,
                                                                borrowRate, 
                                                                activePrincipal, 
                                                                loanStartTime, 
                                                                repaymentInterval);


        if (isLoanExtensionActive == false) {
            // might consider transferring interestDueTillPeriodEnd and refunding the rest
            require(amount < interestDueTillPeriodEnd,
                    "Repayments - amount is greater than interest due this period.");
            
            // TODO add transfer

            uint256 periodCovered = amount.div(interestPerSecond);

            repaymentDetails[poolID].repaymentPeriodCovered = repaymentDetails[poolID].repaymentPeriodCovered
                                                              .add(periodCovered);

            emit InterestRepaid(poolID, amount);

        }
        else {
            if (amount >= repaymentDetails[poolID].repaymentOverdue) {
                repaymentDetails[poolID].repaymentOverdue = 0;
                isLoanExtensionActive = false;
                amount = amount.sub(repaymentDetails[poolID].repaymentOverdue);
                emit MissedRepaymentRepaid(poolID);

                // might consider transferring interestDueTillPeriodEnd and refunding the rest
                require(amount < interestDueTillPeriodEnd,
                        "Repayments - amount is greater than interest due this period.");

                //TODO make token transfer
                uint256 periodCovered = amount.div(interestPerSecond);

                repaymentDetails[poolID].repaymentPeriodCovered = repaymentDetails[poolID].repaymentPeriodCovered
                                                                  .add(periodCovered);
                emit InterestRepaid(poolID, amount);
            }

            else {

                //TODO make token transfer
                repaymentDetails[poolID].repaymentOverdue = repaymentDetails[poolID].repaymentOverdue
                                                            .sub(amount);
                amount = 0;

                emit PartialExtensionRepaymentMade(poolID);
            }
        }

        // returning the status of whether previous interval's interest has been repaid or not
        return isLoanExtensionActive;

    }

    function getTotalRepaidAmount(address poolID) external view returns(uint256) {
        return repaymentDetails[poolID].totalRepaidAmount;
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
        
    }

    function updatePoolFactory(address _poolFactory) external onlyOwner {
        poolFactory = IPoolFactory(_poolFactory);
    }

    function updateVotingExtensionlength(uint256 _votingExtensionPeriod) external onlyOwner {
        votingExtensionlength = _votingExtensionPeriod;
    }

    function updateVotingPassRatio(uint256 _votingPassRatio) external onlyOwner {
        votingPassRatio = _votingPassRatio;
    }
}
