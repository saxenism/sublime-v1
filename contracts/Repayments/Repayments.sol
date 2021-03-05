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


    function calculateCurrentPeriod(
        uint256 loanStartTime,
        uint256 repaymentInterval
    ) public view returns (uint256) {
        
    }

    function interestPerSecond(uint256 _principle, uint256 _borrowRate)
        public
        view
        returns (uint256)
    {
        
    }

    function amountPerPeriod(
        uint256 _activeBorrowAmount,
        uint256 _repaymentInterval,
        uint256 _borrowRate
    ) public view returns (uint256) {
        
    }

    function calculateRepayAmount(
        uint256 activeBorrowAmount,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        uint256 nextDuePeriod,
        uint256 periodInWhichExtensionhasBeenRequested
    ) public view isPoolInitialized returns (uint256, uint256) {
        
    }

    function repayAmount(
        uint256 amount,
        uint256 activeBorrowAmount,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        uint256 nextDuePeriod,
        uint256 periodInWhichExtensionhasBeenRequested
    ) public isPoolInitialized returns (uint256, uint256) {
        
    }

    // function TotalDueamountLeft() public view{
    //     uint256 intervalsLeft = totalNumberOfRepayments-calculateCurrentPeriod();
    //     return(intervalLeft.mul(amountPerPeriod()));
    // }

    function requestExtension(uint256 extensionVoteEndTime)
        external isPoolInitialized
        returns (uint256)
    {
        
    }

    function voteOnExtension(
        address lender,
        uint256 lastVoteTime,
        uint256 extensionVoteEndTime,
        uint256 balance,
        uint256 totalExtensionSupport
    ) external isPoolInitialized returns (uint256, uint256) {
        
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
