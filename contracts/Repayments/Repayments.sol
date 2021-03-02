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

    function initializePool(
        uint256 numberOfTotalRepayments,
        uint256 votingExtensionlength,
        uint256 gracepenaltyRate,
        uint256 gracePeriodInterval,
        uint256 loanDuration
    ) external {

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
}
