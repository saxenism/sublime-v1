// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract PoolToken {

    using SafeMath for uint256;

    enum LoanStatus {
        COLLECTION, //denotes collection period
        ACTIVE, // denotes the active loan
        CLOSED, // Loan is repaid and closed
        CANCELLED, // Cancelled by borrower
        DEFAULTED, // Repaymennt defaulted by  borrower
        TERMINATED // Pool terminated by admin
    }

    function requestExtension(address poolID) external isPoolActive OnlyBorrower {
    	require(IPool(poolID).poolConstants.borrower == msg.sender,
    			"PoolVoting::requestExtension Invalid caller");

    	require(IPool(poolID).poolVars.loanStatus == LoanStatus.ACTIVE,
    			"PoolVoting::requestExtension Invalid pool status");


        uint256 _extensionVoteEndTime = IPool(poolID).poolVars.extensionVoteEndTime;
        require(
            block.timestamp > _extensionVoteEndTime,
            "Pool::requestExtension - Extension requested already"
        );

        // This check is required so that borrower doesn't ask for more extension if previously an extension is already granted
        require(
            IPool(poolID).poolVars.periodWhenExtensionIsPassed > IPool(poolID).poolConstants.noOfRepaymentIntervals,
            "Pool::requestExtension: you have already been given an extension,No more extension"
        );

        IPool(poolID).poolVars.totalExtensionSupport = 0; // As we can multiple voting every time new voting start we have to make previous votes 0
        uint256 _gracePeriodFraction =
            IPoolFactory(PoolFactory).gracePeriodFraction();
        uint256 _gracePeriod =
            (IPool(poolID).poolConstants.repaymentInterval * _gracePeriodFraction).div(100000000);
        uint256 _nextDueTime =
            (poolVars.nextDuePeriod.mul(poolConstants.repaymentInterval)).add(poolConstants.loanStartTime);
        _extensionVoteEndTime = (_nextDueTime).add(_gracePeriod);
        poolVars.extensionVoteEndTime = _extensionVoteEndTime;
        emit extensionRequested(_extensionVoteEndTime);
    }

    function voteOnExtension(address poolID) external isPoolActive {
        uint256 _extensionVoteEndTime = poolVars.extensionVoteEndTime;

    	require(IPool(poolID).poolVars.loanStatus == LoanStatus.ACTIVE,
    			"PoolVoting::voteOnExtension Invalid pool status");

        require(
            block.timestamp < _extensionVoteEndTime,
            "Pool::voteOnExtension - Voting is over"
        );
        require(
            poolToken.balanceOf(msg.sender) != 0,
            "Pool::voteOnExtension - Not a valid lender for pool"
        );

        uint256 _votingExtensionlength =
            IPoolFactory(PoolFactory).votingExtensionlength();
        uint256 _lastVoteTime = lenders[msg.sender].lastVoteTime; //Lender last vote time need to store it as it checks that a lender only votes once

        require(
            _lastVoteTime < _extensionVoteEndTime.sub(_votingExtensionlength),
            "Pool::voteOnExtension - you have already voted"
        );
        
        uint256 _extensionSupport = poolVars.totalExtensionSupport;
        _lastVoteTime = block.timestamp;
        _extensionSupport = _extensionSupport.add(
            poolToken.balanceOf(msg.sender)
        );
        uint256 _votingPassRatio = IPoolFactory(PoolFactory).votingPassRatio();
        lenders[msg.sender].lastVoteTime = _lastVoteTime;
        emit lenderVoted(msg.sender, _extensionSupport, _lastVoteTime);
        poolVars.totalExtensionSupport = _extensionSupport;

        if (
            ((_extensionSupport)) >=
            (poolToken.totalSupply().mul(_votingPassRatio)).div(100000000)
        ) {
            uint256 _currentPeriod = calculateCurrentPeriod();
            uint256 _nextDuePeriod = poolVars.nextDuePeriod;
            uint256 _nextDueTime =
                (_nextDuePeriod.mul(poolConstants.repaymentInterval)).add(poolConstants.loanStartTime);
            uint256 _periodWhenExtensionIsPassed;
            if (block.timestamp > _nextDueTime) {
                _periodWhenExtensionIsPassed = _currentPeriod.sub(1);
            } else {
                _periodWhenExtensionIsPassed = _currentPeriod;
            }
            poolVars.periodWhenExtensionIsPassed = _periodWhenExtensionIsPassed;
            poolVars.extensionVoteEndTime = block.timestamp; // voting is over
            poolVars.nextDuePeriod = _nextDuePeriod.add(1);
            emit votingPassed(_nextDuePeriod.add(1), _periodWhenExtensionIsPassed);
        }
    }


}