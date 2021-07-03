// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IPoolFactory.sol";
import "../interfaces/IExtension.sol";
import "../interfaces/IRepayment.sol";

contract Extension is Initializable, IExtension {
    using SafeMath for uint256;

    uint256 constant MAX_INT = uint256(-1);

    event VotingPassed(uint256 nextDuePeriod); //, uint256 periodWhenExtensionIsPassed); Confirm: do we need to pass the second var?

    struct PoolInfo {
        uint256 periodWhenExtensionIsPassed;
        uint256 totalExtensionSupport;
        uint256 extensionVoteEndTime;
        uint256 repaymentInterval;
        mapping(address => uint256) lastVoteTime;
    }

    mapping(address => PoolInfo) poolInfo;
    IPoolFactory poolFactory;

    event ExtensionRequested(uint256 extensionVoteEndTime);
    event ExtensionPassed(uint256 nextDuePeriod);
    event LenderVoted(
        address lender,
        uint256 totalExtensionSupport,
        uint256 lastVoteTime
    );

    function initialize(address _poolFactory) external initializer {
        poolFactory = IPoolFactory(_poolFactory);
    }

    function initializePoolExtension(uint256 _repaymentInterval)
        external
        override
    {
        IPoolFactory _poolFactory = poolFactory;
        require(poolInfo[msg.sender].repaymentInterval == 0); // TODO missing error code
        require(
            _poolFactory.openBorrowPoolRegistry(msg.sender),
            "Repayments::onlyValidPool - Invalid Pool"
        );
        poolInfo[msg.sender].repaymentInterval = _repaymentInterval;
    }

    function requestExtension(address _pool) external {
        uint256 _repaymentInterval = poolInfo[_pool].repaymentInterval;
        require(_repaymentInterval != 0);
        uint256 _extensionVoteEndTime = poolInfo[_pool].extensionVoteEndTime;
        require(
            block.timestamp > _extensionVoteEndTime,
            "Extension::requestExtension - Extension requested already"
        ); // _extensionVoteEndTime is 0 when no extension is active


        // This check is required so that borrower doesn't ask for more extension if previously an extension is already granted
        require(
            poolInfo[_pool].periodWhenExtensionIsPassed == MAX_INT,
            "Extension::requestExtension: you have already been given an extension,No more extension"
        );

        poolInfo[_pool].totalExtensionSupport = 0; // As we can multiple voting every time new voting start we have to make previous votes 0
        uint256 _gracePeriodFraction = poolFactory.gracePeriodFraction();
        uint256 _gracePeriod =
            (_repaymentInterval * _gracePeriodFraction).div(10**30); // multiplying exponents
        uint256 _nextDueTime =
            IPool(_pool).getNextDueTimeIfBorrower(msg.sender);
        _extensionVoteEndTime = (_nextDueTime).add(_gracePeriod);
        poolInfo[_pool].extensionVoteEndTime = _extensionVoteEndTime; // TODO this makes extension request single use, ideally need to reset extensionVoteEndTime if vote doesnt cross threshold
        emit ExtensionRequested(_extensionVoteEndTime);
    }

    function voteOnExtension(address _pool) external {
        uint256 _extensionVoteEndTime = poolInfo[_pool].extensionVoteEndTime;
        require(
            block.timestamp < _extensionVoteEndTime,
            "Pool::voteOnExtension - Voting is over"
        );

        (uint256 _balance, uint256 _totalSupply) =
            IPool(_pool).getBalanceDetails(msg.sender);
        require(
            _balance != 0,
            "Pool::voteOnExtension - Not a valid lender for pool"
        );

        uint256 _votingPassRatio = IPoolFactory(poolFactory).votingPassRatio();

        uint256 _lastVoteTime = poolInfo[_pool].lastVoteTime[msg.sender]; //Lender last vote time need to store it as it checks that a lender only votes once
        uint256 _gracePeriodFraction = poolFactory.gracePeriodFraction();
        uint256 _repaymentInterval = poolInfo[_pool].repaymentInterval;
        uint256 _gracePeriod =
            (_repaymentInterval * _gracePeriodFraction).div(100000000);
        require(
            _lastVoteTime <
                _extensionVoteEndTime.sub(_gracePeriod).sub(_repaymentInterval),
            "Pool::voteOnExtension - you have already voted"
        );

        uint256 _extensionSupport = poolInfo[_pool].totalExtensionSupport;
        _lastVoteTime = block.timestamp;
        _extensionSupport = _extensionSupport.add(_balance);

        poolInfo[_pool].lastVoteTime[msg.sender] = _lastVoteTime;
        emit LenderVoted(msg.sender, _extensionSupport, _lastVoteTime);
        poolInfo[_pool].totalExtensionSupport = _extensionSupport;

        if (
            ((_extensionSupport)) >=
            (_totalSupply.mul(_votingPassRatio)).div(10**30)
        ) {
            grantExtension(_pool);
            // TODO: probably delete the lastVoteTime as that is not needed in future
        }
    }

    function grantExtension(address _pool) internal {
        IPoolFactory _poolFactory = poolFactory;

        uint256 _currentLoanInterval = IRepayment(_poolFactory.repaymentImpl()).getCurrentLoanInterval(_pool);
        poolInfo[_pool].periodWhenExtensionIsPassed = _currentLoanInterval;
        poolInfo[_pool].extensionVoteEndTime = block.timestamp; // voting is over

        IRepayment(_poolFactory.repaymentImpl()).instalmentDeadlineExtended(_pool, _currentLoanInterval);

        emit ExtensionPassed(_currentLoanInterval);
    }

    function closePoolExtension() external override {
        delete poolInfo[msg.sender];
    }
}
