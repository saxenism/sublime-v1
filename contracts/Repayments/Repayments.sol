// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./RepaymentStorage.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IRepayment.sol";
import "../interfaces/ISavingsAccount.sol";

import "hardhat/console.sol";

contract Repayments is RepaymentStorage, IRepayment {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address PoolFactory;

    event InterestRepaid(address poolID, uint256 repayAmount); // Made during current period interest repayment
    event MissedRepaymentRepaid(address poolID); // Previous period's interest is repaid fully
    event PartialExtensionRepaymentMade(address poolID); // Previous period's interest is repaid partially

    modifier isPoolInitialized() {
        require(
            repaymentConstants[msg.sender].numberOfTotalRepayments != 0,
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
        uint256 _gracePenalityRate,
        uint256 _gracePeriodFraction,
        address _savingsAccount
    ) public initializer {
        // _votingExtensionlength - should enforce conditions with repaymentInterval
        OwnableUpgradeable.__Ownable_init();
        OwnableUpgradeable.transferOwnership(_owner);

        votingPassRatio = _votingPassRatio;
        PoolFactory = _poolFactory;
        savingsAccount = _savingsAccount;
        gracePenaltyRate = _gracePenalityRate;
        gracePeriodFraction = _gracePeriodFraction;
    }

    function initializeRepayment(
        uint256 numberOfTotalRepayments,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        address lentAsset
    ) external override onlyValidPool {
        repaymentConstants[msg.sender].gracePenaltyRate = gracePenaltyRate;
        repaymentConstants[msg.sender]
            .gracePeriodFraction = gracePeriodFraction;
        repaymentConstants[msg.sender]
            .numberOfTotalRepayments = numberOfTotalRepayments;
        repaymentConstants[msg.sender].loanDuration = repaymentInterval.mul(
            numberOfTotalRepayments
        );
        repaymentConstants[msg.sender].repaymentInterval = repaymentInterval;
        repaymentConstants[msg.sender].borrowRate = borrowRate;
        repaymentConstants[msg.sender].loanStartTime = loanStartTime;
        repaymentConstants[msg.sender].repayAsset = lentAsset;
        repaymentConstants[msg.sender].savingsAccount = savingsAccount;
        //repaymentVars[msg.sender].nextDuePeriod = loanStartTime.add(repaymentInterval); TODO is this necessary
        repaymentVars[msg.sender].nInstalmentsFullyPaid = 0;
    }

    /*
     * @notice returns the number of repayment intervals that have been repaid,
     * if repayment interval = 10 secs, loan duration covered = 55 secs, repayment intervals covered = 5
     * @param _poolID address of the pool
     */

    function getInterestPerSecond(address _poolID)
        public
        view
        returns (uint256)
    {
        uint256 _activePrincipal = IPool(_poolID).getTotalSupply();
        uint256 _interestPerSecond =
            _activePrincipal.mul(repaymentConstants[_poolID].borrowRate).div(
                yearInSeconds
            );
        return _interestPerSecond;
    }

    function getInstalmentsCompleted(address _poolID)
        public
        view
        returns (uint256)
    {
        uint256 _repaymentInterval =
            repaymentConstants[_poolID].repaymentInterval;
        uint256 _loanDurationCovered =
            repaymentVars[_poolID].loanDurationCovered;

        uint256 _instalmentsCompleted =
            _loanDurationCovered.mul(10**30).div(_repaymentInterval); // dividing exponents, returns whole number rounded down

        return _instalmentsCompleted;
    }

    function getInterestDueTillInstalmentDeadline(address _poolID)
        public
        view
        returns (uint256)
    {
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);
        uint256 _nextInstalmentDeadline = getNextInstalmentDeadline(_poolID);
        uint256 _loanDurationCovered =
            repaymentVars[_poolID].loanDurationCovered;

        uint256 _interestDueTillInstalmentDeadline =
            (_nextInstalmentDeadline.sub(_loanDurationCovered)).mul(
                _interestPerSecond
            );

        return _interestDueTillInstalmentDeadline;
    }

    /*
    function updateLoanExtensionPeriod(address _poolID, uint256 _period) 
        external 
    {
        repaymentVars[_poolID].loanExtensionPeriod = _period;
    }*/

    function getNextInstalmentDeadline(address _poolID)
        public
        view
        override
        returns (uint256)
    {
        uint256 _instalmentsCompleted = getInstalmentsCompleted(_poolID);
        uint256 _loanExtensionPeriod =
            repaymentVars[_poolID].loanExtensionPeriod;
        uint256 _repaymentInterval =
            repaymentConstants[_poolID].repaymentInterval;
        uint256 _loanStartTime = repaymentConstants[_poolID].loanStartTime;
        uint256 _nextInstalmentDeadline;

        //uint256 _ extensions on impro

        if (_loanExtensionPeriod > _instalmentsCompleted) {
            _nextInstalmentDeadline = (
                (_instalmentsCompleted.add(10**30).add(10**30)).mul(
                    _repaymentInterval
                )
            )
                .add(_loanStartTime);
        } else {
            _nextInstalmentDeadline = (
                (_instalmentsCompleted.add(10**30)).mul(_repaymentInterval)
            )
                .add(_loanStartTime);
        }

        return _nextInstalmentDeadline;
    }

    function getCurrentInstalmentInterval(address _poolID)
        public
        view
        returns (uint256)
    {
        uint256 _instalmentsCompleted = getInstalmentsCompleted(_poolID);
        return _instalmentsCompleted.add(10**30);
    }

    function getCurrentLoanInterval(address _poolID)
        external
        view
        override
        returns (uint256)
    {
        uint256 _loanStartTime = repaymentConstants[_poolID].loanStartTime;
        uint256 _currentTime = block.timestamp;
        uint256 _repaymentInterval =
            repaymentConstants[_poolID].repaymentInterval;
        uint256 _currentInterval =
            (
                (_currentTime.sub(_loanStartTime)).mul(10**30).div(
                    _repaymentInterval
                )
            )
                .add(10**30); // TODO add 10**30 to add 1 - check

        return _currentInterval;
    }

    function isGracePenaltyApplicable(address _poolID)
        public
        view
        returns (bool)
    {
        //uint256 _loanStartTime = repaymentConstants[_poolID].loanStartTime;
        uint256 _repaymentInterval =
            repaymentConstants[_poolID].repaymentInterval;
        uint256 _currentTime = block.timestamp;
        uint256 _gracePeriodFraction =
            repaymentConstants[_poolID].gracePeriodFraction;
        uint256 _nextInstalmentDeadline = getNextInstalmentDeadline(_poolID);
        uint256 _gracePeriodDeadline =
            _nextInstalmentDeadline.add(
                _gracePeriodFraction.mul(_repaymentInterval)
            );

        require(_currentTime <= _gracePeriodDeadline, "Borrower has defaulted");

        if (_currentTime <= _nextInstalmentDeadline) return false;
        else return true;
    }

    function didBorrowerDefault(address _poolID)
        public
        view
        override
        returns (bool)
    {
        uint256 _currentTime = block.timestamp;
        uint256 _instalmentDeadline = getNextInstalmentDeadline(_poolID);

        if (_currentTime > _instalmentDeadline) return true;
        else return false;
    }

    /*
    function calculateRepayAmount(address poolID)
        public
        view
        override
        returns (uint256)
    {
        uint256 activePrincipal = IPool(poolID).getTotalSupply();
        // assuming repaymentInterval is in seconds
        //uint256 currentPeriod = (block.timestamp.sub(repaymentConstants[poolID].loanStartTime)).div(repaymentConstants[poolID].repaymentInterval);

        uint256 interestPerSecond =
            activePrincipal.mul(repaymentConstants[poolID].borrowRate).div(
                yearInSeconds
            );

        // uint256 periodEndTime = (currentPeriod.add(1)).mul(repaymentInterval);

        uint256 interestDueTillPeriodEnd =
            interestPerSecond.mul(
                (repaymentConstants[poolID].repaymentInterval).sub(
                    repaymentVars[poolID].repaymentPeriodCovered
                )
            );
        return interestDueTillPeriodEnd;
    }
*/
    // TODO need to add grace penalty

    function getInterestLeft(address _poolID) public view returns (uint256) {
        uint256 _interestPerSecond = getInterestPerSecond((_poolID));
        uint256 _loanDurationLeft =
            repaymentConstants[_poolID].loanDuration.sub(
                repaymentVars[_poolID].loanDurationCovered
            );
        uint256 _interestLeft =
            _interestPerSecond.mul(_loanDurationLeft).div(10**30); // multiplying exponents

        return _interestLeft;
    }

    function getInterestOverdue(address _poolID) public view returns (uint256) {
        uint256 _instalmentsCompleted = getInstalmentsCompleted(_poolID);
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);
        uint256 _interestOverdue =
            (
                (
                    (_instalmentsCompleted.add(10**30)).mul(
                        repaymentConstants[_poolID].repaymentInterval
                    )
                )
                    .sub(repaymentVars[_poolID].loanDurationCovered)
            )
                .mul(_interestPerSecond);
        return _interestOverdue;
    }

    function repayAmount(address _poolID, uint256 _amount)
        public
        payable
        isPoolInitialized
    {
        IPool _pool = IPool(_poolID);

        uint256 _loanStatus = _pool.getLoanStatus();
        require(
            _loanStatus == 1,
            "Repayments:repayInterest Pool should be active."
        );

        uint256 _amountRequired = 0;
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);

        // First pay off the overdue
        if (repaymentVars[_poolID].isLoanExtensionActive == true) {
            uint256 _interestOverdue = getInterestOverdue(_poolID);

            if (_amount >= _interestOverdue) {
                _amount = _amount.sub(_interestOverdue);
                _amountRequired = _amountRequired.add(_interestOverdue);
                repaymentVars[_poolID].isLoanExtensionActive = false; // deactivate loan extension flag
                repaymentVars[_poolID].loanDurationCovered = (
                    getInstalmentsCompleted(_poolID).add(10**30)
                )
                    .mul(repaymentConstants[_poolID].repaymentInterval);
            } else {
                _amount = 0;
                _amountRequired = _amountRequired.add(_amount);
                repaymentVars[_poolID].loanDurationCovered = repaymentVars[
                    _poolID
                ]
                    .loanDurationCovered
                    .add(_amount.mul(10**30).div(_interestPerSecond));
            }
        }

        // Second pay off the interest
        if (_amount != 0) {
            uint256 _interestLeft = getInterestLeft(_poolID);
            bool _isBorrowerLate = isGracePenaltyApplicable(_poolID);

            // adding grace penalty if applicable
            if (_isBorrowerLate) {
                uint256 _penalty =
                    repaymentConstants[_poolID]
                        .gracePenaltyRate
                        .mul(_interestLeft)
                        .div(10**30);
                _interestLeft = _interestLeft.add(_penalty);
            }

            if (_amount < _interestLeft) {
                uint256 _loanDurationCovered =
                    _amount.mul(10**30).div(_interestPerSecond); // dividing exponents
                repaymentVars[_poolID].loanDurationCovered = repaymentVars[
                    _poolID
                ]
                    .loanDurationCovered
                    .add(_loanDurationCovered);
                _amount = 0;
                _amountRequired = _amountRequired.add(_amount);
            } else {
                repaymentVars[_poolID].loanDurationCovered = repaymentConstants[
                    _poolID
                ]
                    .loanDuration; // full interest repaid
                _amount = _amount.sub(_interestLeft);
                _amountRequired = _amountRequired.add(_interestLeft);
            }
        }

        address _asset = repaymentConstants[_poolID].repayAsset;

        if (_asset == address(0)) {
            require(
                _amountRequired <= msg.value,
                "Repayments::repayAmount amount does not match message value."
            );
            payable(address(_poolID)).transfer(_amountRequired);
        } else {
            IERC20(_asset).transferFrom(msg.sender, _poolID, _amountRequired);
        }

        if (_asset == address(0)) {
            if (msg.value > _amountRequired) {
                payable(address(msg.sender)).transfer(
                    msg.value.sub(_amountRequired)
                );
            }
        }
    }

    // TODO should this be calling closeLoan() or the other way around?
    function repayPrincipal(address payable _poolID, uint256 _amount)
        public
        payable
        isPoolInitialized
    {
        IPool _pool = IPool(_poolID);
        uint256 _loanStatus = _pool.getLoanStatus();
        require(
            _loanStatus == 1,
            "Repayments:repayPrincipal Pool should be active"
        );

        require(
            repaymentVars[_poolID].isLoanExtensionActive == false,
            "Repayments:repayPrincipal Repayment overdue unpaid"
        );

        require(
            repaymentConstants[_poolID].loanDuration ==
                repaymentVars[_poolID].loanDurationCovered,
            "Repayments:repayPrincipal Unpaid interest"
        );

        uint256 _activePrincipal = _pool.getTotalSupply();
        require(
            _amount == _activePrincipal,
            "Repayments:repayPrincipal Amount should match the principal"
        );

        address _asset = repaymentConstants[_poolID].repayAsset;

        if (_asset == address(0)) {
            require(
                _amount == msg.value,
                "Repayments::repayAmount amount does not match message value."
            );
            _poolID.transfer(_amount);
        } else {
            IERC20(_asset).transferFrom(msg.sender, _poolID, _amount);
        }

        IPool(_poolID).closeLoan();
    }

    /*
    function getRepaymentPeriodCovered(address poolID) external view override returns(uint256) {
        return repaymentVars[poolID].repaymentPeriodCovered;
    }
    */
    function getTotalRepaidAmount(address poolID)
        external
        view
        override
        returns (uint256)
    {
        return repaymentVars[poolID].totalRepaidAmount;
    }

    function instalmentDeadlineExtended(address _poolID, uint256 _period)
        external
        override
    {
        require(
            msg.sender == IPoolFactory(PoolFactory).owner(),
            "Repayments::repaymentExtended - Invalid caller"
        );

        repaymentVars[_poolID].isLoanExtensionActive = true;
        repaymentVars[_poolID].loanExtensionPeriod = _period;
    }

    function getInterestCalculationVars(address _poolID)
        external
        view
        override
        returns (uint256, uint256)
    {
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);
        return (repaymentVars[_poolID].loanDurationCovered, _interestPerSecond);
    }

    function getGracePeriodFraction() external view override returns (uint256) {
        return gracePeriodFraction;
    }
}
