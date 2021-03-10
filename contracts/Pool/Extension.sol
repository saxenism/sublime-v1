// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IPoolFactory.sol";

contract Extension is Initializable {

    uint256 constant MAX_INT = "";

    struct PoolInfo {
        uint256 periodWhenExtensionIsPassed;
        uint256 totalExtensionSupport;
        uint256 extensionVoteEndTime;
        uint256 repaymentInterval;
        mapping(address => uint256) lastVoteTime;
    }

    mapping(address => PoolInfo) poolInfo;
    IPoolFactory poolFactory;

    function initialize(address _poolFactory) external initializer {
        poolFactory = IPoolFactory(_poolFactory);
    }

    function initializeExtension(uint256 _repaymentInterval) external {
        IPoolFactory _poolFactory = poolFactory;
        require(poolInfo[msg.sender].repaymentInterval == 0);
        require(_poolFactory.openBorrowPoolRegistry(msg.sender), "Repayments::onlyValidPool - Invalid Pool");
        // TODO: Initialize this when borrower accepts loan
        // TODO: Delete this  when loan ends for whatever reason
        poolInfo[msg.sender].repaymentInterval = _repaymentInterval;
    }

    function requestExtension(address _pool) external {
        uint256 _repaymentInterval = poolInfo[_pool].repaymentInterval;
        require(_repaymentInterval != 0);
        IPool pool = IPool(_pool);
        // TODO: Combine this with the call to pool contract below
        require(pool.borrower() == msg.sender);
        uint256 _extensionVoteEndTime = poolInfo[_pool].extensionVoteEndTime;
        require(
            block.timestamp > _extensionVoteEndTime,
            "Extension::requestExtension - Extension requested already"
        );

        // This check is required so that borrower doesn't ask for more extension if previously an extension is already granted
        // TODO: Instead set periodWhenExtensionIsPassed to very high number so that noOfRepaymentIntervals is not needed
        require(
            poolInfo[_pool].periodWhenExtensionIsPassed == MAX_INT,
            "Extension::requestExtension: you have already been given an extension,No more extension"
        );

        poolInfo[_pool].totalExtensionSupport = 0; // As we can multiple voting every time new voting start we have to make previous votes 0
        uint256 _gracePeriodFraction = poolFactory.gracePeriodFraction();
        uint256 _gracePeriod =
            (_repaymentInterval * _gracePeriodFraction).div(100000000);
        // TODO: Create a fn in Pool for this and call that fn instead
        uint256 _nextDueTime = pool.getNextDuePeriod();
        // uint256 _nextDueTime =
        //     (poolVars.nextDuePeriod.mul(poolInfo.repaymentInterval)).add(poolConstants.loanStartTime);
        _extensionVoteEndTime = (_nextDueTime).add(_gracePeriod);
        poolInfo[_pool].extensionVoteEndTime = _extensionVoteEndTime;
        emit extensionRequested(_extensionVoteEndTime);
    }

    function voteOnExtension(address _pool) external isPoolActive {
        uint256 _extensionVoteEndTime = poolInfo[_pool].extensionVoteEndTime;
        require(
            block.timestamp < _extensionVoteEndTime,
            "Pool::voteOnExtension - Voting is over"
        );
        // TODO: This belongs in pool
        uint256 _balance = poolToken.balanceOf(msg.sender);
        require(
            _balance != 0,
            "Pool::voteOnExtension - Not a valid lender for pool"
        );
        // TODO: Merge this with  another call to poolfactory below
        uint256 _votingExtensionlength =
            IPoolFactory(PoolFactory).votingExtensionlength();
        uint256 _lastVoteTime = poolInfo[_pool].lastVoteTime[msg.sender]; //Lender last vote time need to store it as it checks that a lender only votes once

        require(
            _lastVoteTime < _extensionVoteEndTime.sub(_votingExtensionlength),
            "Pool::voteOnExtension - you have already voted"
        );
        
        uint256 _extensionSupport = poolInfo[_pool].totalExtensionSupport;
        _lastVoteTime = block.timestamp;
        _extensionSupport = _extensionSupport.add(
            _balance
        );
        uint256 _votingPassRatio = IPoolFactory(PoolFactory).votingPassRatio();
        poolInfo[_pool].lastVoteTime[msg.sender] = _lastVoteTime;
        emit lenderVoted(msg.sender, _extensionSupport, _lastVoteTime);
        poolInfo[_pool].totalExtensionSupport = _extensionSupport;

        if (
            ((_extensionSupport)) >=
            (poolToken.totalSupply().mul(_votingPassRatio)).div(100000000)
        ) {
            grantExtension(_pool);
        }
    }

    function grantExtension(address _pool) internal {
        // uint256 _currentPeriod = calculateCurrentPeriod();
        // TODO: This probably belongs in repayments, update the nextDuePeriod
        IPool(_pool).grantExtension();

        poolVars.periodWhenExtensionIsPassed = MAX_INT;
        poolVars.extensionVoteEndTime = block.timestamp; // voting is over
        // TODO: This belongs in pool
        // poolVars.nextDuePeriod = _nextDuePeriod.add(1);
        emit votingPassed(_nextDuePeriod.add(1));
    }
}