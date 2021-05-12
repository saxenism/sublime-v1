// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./RepaymentStorage.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IRepayment.sol";
import "../interfaces/ISavingsAccount.sol";

contract Repayments is RepaymentStorage, IRepayment {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address PoolFactory;

    modifier isPoolInitialized() {
        require(
            repaymentDetails[msg.sender].numberOfTotalRepayments != 0,
            "Pool is not Initiliazed"
        );
        _;
    }

    modifier onlyValidPool {
        require(
            IPoolFactory(PoolFactory).openBorrowPoolRegistry(msg.sender),
            "Repayments::onlyValidPool - Invalid Pool"
        );
        _;
    }

    function initialize(
        address _owner,
        address _poolFactory,
        uint256 _votingPassRatio,
        address _savingsAccount
    ) public initializer {
        // _votingExtensionlength - should enforce conditions with repaymentInterval
        OwnableUpgradeable.__Ownable_init();
        OwnableUpgradeable.transferOwnership(_owner);

        votingPassRatio = _votingPassRatio;
        PoolFactory = _poolFactory;
        savingsAccount = _savingsAccount;
    }

    function initializeRepayment(
        uint256 numberOfTotalRepayments,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        address lentAsset
    ) external override onlyValidPool {
        repaymentDetails[msg.sender].gracePenaltyRate = gracePenaltyRate;
        repaymentDetails[msg.sender].gracePeriodFraction = gracePeriodFraction;
        repaymentDetails[msg.sender]
            .numberOfTotalRepayments = numberOfTotalRepayments;
        repaymentDetails[msg.sender].loanDuration = repaymentInterval.mul(
            numberOfTotalRepayments
        );
        repaymentDetails[msg.sender].repaymentInterval = repaymentInterval;
        repaymentDetails[msg.sender].borrowRate = borrowRate;
        repaymentDetails[msg.sender].loanStartTime = loanStartTime;
        repaymentDetails[msg.sender].repayAsset = lentAsset;
        repaymentDetails[msg.sender].savingsAccount = savingsAccount;
    }

    function calculateRepayAmount(address poolID, uint256 principle)
        public
        view
        override
        returns (uint256)
    {
        uint256 activePrincipal = IPool(poolID).getTotalSupply();
        // assuming repaymentInterval is in seconds
        //uint256 currentPeriod = (block.timestamp.sub(repaymentDetails[poolID].loanStartTime)).div(repaymentDetails[poolID].repaymentInterval);

        uint256 interestPerSecond =
            activePrincipal.mul(repaymentDetails[poolID].borrowRate).div(
                yearInSeconds
            );

        // uint256 periodEndTime = (currentPeriod.add(1)).mul(repaymentInterval);

        uint256 interestDueTillPeriodEnd =
            interestPerSecond.mul(
                (repaymentDetails[poolID].repaymentInterval).sub(
                    repaymentDetails[poolID].repaymentPeriodCovered
                )
            );
        return interestDueTillPeriodEnd;
    }

    event InterestRepaid(address poolID, uint256 repayAmount); // Made during current period interest repayment
    event MissedRepaymentRepaid(address poolID); // Previous period's interest is repaid fully
    event PartialExtensionRepaymentMade(address poolID); // Previous period's interest is repaid partially

    function repayAmount(address poolID, uint256 amount)
        public
        payable
        isPoolInitialized
    {

        uint256 _loanStatus = IPool(poolID).getLoanStatus();
        require(
            _loanStatus == 1,
            "Repayments:repayAmount Pool should be active."
        );

        uint256 activePrincipal = IPool(poolID).getTotalSupply();

        uint256 interestPerSecondScaled = activePrincipal
            .mul(repaymentDetails[poolID].borrowRate)
            .div(yearInSeconds);

        uint256 interestDueTillPeriodEndScaled =
            interestPerSecondScaled.mul(
                (repaymentDetails[poolID].repaymentInterval).sub(
                    repaymentDetails[poolID].repaymentPeriodCovered
                )
            );

        address asset = repaymentDetails[poolID].repayAsset;

        if (asset == address(0)) {
            require(
                amount == msg.value,
                "Repayments::repayAmount amount does not match message value."
            );
        } else {
            ISavingsAccount(savingsAccount).depositTo(
                amount,
                asset,
                address(0),
                poolID
            );
        }

        if (
            repaymentDetails[poolID].isLoanExtensionActive == false ||
            (amount >= repaymentDetails[poolID].repaymentOverdue)
        ) {
            if (repaymentDetails[poolID].isLoanExtensionActive) {
                amount = amount.sub(repaymentDetails[poolID].repaymentOverdue);
                repaymentDetails[poolID].repaymentOverdue = 0;
                repaymentDetails[poolID].isLoanExtensionActive = false;
                emit MissedRepaymentRepaid(poolID);
                repaymentDetails[poolID].totalRepaidAmount = repaymentDetails[
                    poolID
                ]
                    .totalRepaidAmount
                    .add(amount);
            }
            require(
                amount <= interestDueTillPeriodEndScaled,
                "Repayments - amount is greater than interest due this period."
            );

            uint256 periodCovered = amount.div(interestPerSecondScaled);

            if (
                repaymentDetails[poolID].repaymentPeriodCovered.add(
                    periodCovered
                ) == repaymentDetails[poolID].repaymentInterval
            ) {
                repaymentDetails[poolID].repaymentPeriodCovered = 0;
            } else {
                repaymentDetails[poolID]
                    .repaymentPeriodCovered = repaymentDetails[poolID]
                    .repaymentPeriodCovered
                    .add(periodCovered);
            }

            emit InterestRepaid(poolID, amount);
        } else {
            if (amount < repaymentDetails[poolID].repaymentOverdue) {
                repaymentDetails[poolID].repaymentOverdue = repaymentDetails[
                    poolID
                ]
                    .repaymentOverdue
                    .sub(amount);
                repaymentDetails[poolID].totalRepaidAmount = repaymentDetails[
                    poolID
                ]
                    .totalRepaidAmount
                    .add(amount);
                amount = 0;

                emit PartialExtensionRepaymentMade(poolID);
            }
        }
    }

    /*
    function getRepaymentPeriodCovered(address poolID) external view override returns(uint256) {
        return repaymentDetails[poolID].repaymentPeriodCovered;
    }
    */
    function getTotalRepaidAmount(address poolID)
        external
        view
        override
        returns (uint256)
    {
        return repaymentDetails[poolID].totalRepaidAmount;
    }

    /*
    function getRepaymentOverdue(address poolID) external view override returns(uint256) {
        return repaymentDetails[poolID].repaymentOverdue;
    }
    */
    function repaymentExtended(address poolID) external override {
        require(
            msg.sender == IPoolFactory(PoolFactory).owner(),
            "Repayments::repaymentExtended - Invalid caller"
        );

        repaymentDetails[poolID].isLoanExtensionActive = true;
        uint256 activePrincipal = IPool(poolID).getTotalSupply();

        uint256 interestPerSecond =
            activePrincipal.mul(repaymentDetails[poolID].borrowRate).div(
                yearInSeconds
            );

        uint256 _repaymentOverdue =
            (
                (repaymentDetails[poolID].repaymentInterval).sub(
                    repaymentDetails[poolID].repaymentPeriodCovered
                )
            )
                .mul(interestPerSecond);
        repaymentDetails[poolID].repaymentOverdue = _repaymentOverdue;
    }

    function getInterestCalculationVars(address poolID)
        external
        view
        override
        returns (uint256, uint256)
    {
        return (
            repaymentDetails[poolID].repaymentPeriodCovered,
            repaymentDetails[poolID].repaymentOverdue
        );
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
