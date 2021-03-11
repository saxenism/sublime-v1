// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./RepaymentStorage.sol";
import "../interfaces/IPool.sol";

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

    modifier onlyOwner {
        require(
            msg.sender == IPoolFactory(PoolFactory).owner(),
            "Pool::onlyOwner - Only owner can invoke"
        );
        _;
    }

    modifier onlyValidPool {
        require(poolFactory.openBorrowPoolRegistry(msg.sender), "Repayments::onlyValidPool - Invalid Pool");
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
    ) external onlyValidPool override {
        repaymentDetails[msg.sender].gracePenaltyRate = gracePenaltyRate;
        repaymentDetails[msg.sender].gracePeriodFraction = gracePeriodFraction;
        repaymentDetails[msg.sender].numberOfTotalRepayments = numberOfTotalRepayments;
        repaymentDetails[msg.sender].loanDuration = repaymentInterval.mul(numberOfTotalRepayments);
        repaymentDetails[msg.sender].repaymentInterval = repaymentInterval;
    }


    function calculateRepayAmount(
        address poolID,
        uint256 borrowRate,
        uint256 loanStartTime
        ) public view override returns(uint256) {

        uint256 activePrincipal = IPool(poolID).getTotalSupply();
        // assuming repaymentInterval is in seconds
        uint256 currentPeriod = (block.timestamp.sub(loanStartTime)).div(repaymentDetails[poolID].repaymentInterval);

        uint256 interestPerSecond = activePrincipal.mul(borrowRate).div(yearInSeconds);

        // uint256 periodEndTime = (currentPeriod.add(1)).mul(repaymentInterval);

        uint256 interestDueTillPeriodEnd = interestPerSecond.mul((repaymentDetails[poolID].repaymentInterval)
                                                            .sub(repaymentDetails[poolID].repaymentPeriodCovered));
        return interestDueTillPeriodEnd;
    }

    event InterestRepaid(address poolID, uint256 repayAmount); // Made during current period interest repayment
    event MissedRepaymentRepaid(address poolID); // Previous period's interest is repaid fully
    event PartialExtensionRepaymentMade(address poolID); // Previous period's interest is repaid partially

    function repayAmount(
        address poolID,
        uint256 amount,
        uint256 borrowRate,
        uint256 loanStartTime,
        address asset
    ) public isPoolInitialized payable {
        //repayAmount() in Pool.sol is already performing pool status check - confirm this

        uint256 _loanStatus = IPool(poolID).getLoanStatus();
        require(_loanStatus == 1, "Repayments:repayAmount Pool should be active.");
        
        // assuming repaymentInterval is in seconds

        uint256 interestPerSecond;
        uint256 interestDueTillPeriodEnd;
        uint256 activePrincipal = IPool(poolID).getTotalSupply();

        interestPerSecond = activePrincipal.mul(borrowRate).div(yearInSeconds);

        interestDueTillPeriodEnd = calculateRepayAmount(poolID,
                                                            borrowRate, 
                                                            loanStartTime);

        if (repaymentDetails[poolID].isLoanExtensionActive == false) {
            // might consider transferring interestDueTillPeriodEnd and refunding the rest
            require(amount <= interestDueTillPeriodEnd,
                    "Repayments - amount is greater than interest due this period.");

            //if asset == address(0), payable function receives tokens in contract
            if (asset == address(0)) {
                require(amount == msg.value, "Repayments::repayAmount amount does not match message value.");
            }

            else {
                //add check to see if user has sufficient asset balance?
                IERC20(asset).transferFrom(msg.sender, address(this), amount);
            }

            uint256 periodCovered = amount.div(interestPerSecond);

            //repaymentDetails[poolID].repaymentPeriodCovered = repaymentDetails[poolID].repaymentPeriodCovered
            //                                                 .add(periodCovered);
            if(repaymentDetails[poolID].repaymentPeriodCovered.add(periodCovered) == repaymentDetails[poolID].repaymentInterval) {
                repaymentDetails[poolID].repaymentPeriodCovered = 0;
            }
            else{
                repaymentDetails[poolID].repaymentPeriodCovered = repaymentDetails[poolID].repaymentPeriodCovered
                                                                  .add(periodCovered);
            }

            emit InterestRepaid(poolID, amount);

        }
        else {
            if (amount >= repaymentDetails[poolID].repaymentOverdue) {
                if (asset == address(0)) {
                    require(amount == msg.value, "Repayments::repayAmount amount does not match message value.");
                }

                else {
                    //add check to see if user has sufficient asset balance?
                    IERC20(asset).transferFrom(msg.sender, address(this), amount);
                }
                
                amount = amount.sub(repaymentDetails[poolID].repaymentOverdue);
                repaymentDetails[poolID].repaymentOverdue = 0;
                repaymentDetails[poolID].isLoanExtensionActive = false;
                emit MissedRepaymentRepaid(poolID);

                // might consider transferring interestDueTillPeriodEnd and refunding the rest
                require(amount < interestDueTillPeriodEnd,
                        "Repayments - amount is greater than interest due this period.");

                uint256 periodCovered = amount.div(interestPerSecond);

                if(repaymentDetails[poolID].repaymentPeriodCovered.add(periodCovered) == repaymentDetails[poolID].repaymentInterval) {
                    repaymentDetails[poolID].repaymentPeriodCovered = 0;
                }
                else{
                    repaymentDetails[poolID].repaymentPeriodCovered = repaymentDetails[poolID].repaymentPeriodCovered
                                                                      .add(periodCovered);
                }
                repaymentDetails[poolID].totalRepaidAmount = repaymentDetails[poolID].totalRepaidAmount.add(amount);
                emit InterestRepaid(poolID, amount);
            }

            else {
                if (asset == address(0)) {
                    require(amount == msg.value, "Repayments::repayAmount amount does not match message value.");
                }

                else {
                    //add check to see if user has sufficient asset balance?
                    IERC20(asset).transferFrom(msg.sender, address(this), amount);
                }

                repaymentDetails[poolID].repaymentOverdue = repaymentDetails[poolID].repaymentOverdue
                                                            .sub(amount);
                repaymentDetails[poolID].totalRepaidAmount = repaymentDetails[poolID].totalRepaidAmount.add(amount);
                amount = 0;

                emit PartialExtensionRepaymentMade(poolID);
            }
        }

    }

    function getRepaymentPeriodCovered(address poolID) external view override returns(uint256) {
        return repaymentDetails[poolID].repaymentPeriodCovered;
    }

    function getTotalRepaidAmount(address poolID) external view override returns(uint256) {
        return repaymentDetails[poolID].totalRepaidAmount;
    }

    function getRepaymentOverdue(address poolID) external view override returns(uint256) {
        return repaymentDetails[poolID].repaymentOverdue;
    }

    function repaymentExtended(address poolID) external override onlyOwner(msg.sender) {
        repaymentDetails[poolID].isLoanExtensionActive = true;
        uint256 activePrincipal = IPool(poolID).getTotalSupply();

        uint256 interestPerSecond = activePrincipal.mul(borrowRate).div(yearInSeconds);

        uint256 _repaymentOverdue = ((repaymentDetails[poolID].repaymentInterval)
                                      .sub(repaymentDetails[poolID].repaymentPeriodCovered)).mul(interestPerSecond);
        repaymentDetails[poolID].repaymentOverdue = _repaymentOverdue;
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


    /*function voteOnExtension(address poolID,
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
    }*/
}
