// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import './RepaymentStorage.sol';
import '../interfaces/IPool.sol';
import '../interfaces/IRepayment.sol';
import '../interfaces/ISavingsAccount.sol';

/**
 * @title Repayments contract
 * @dev For accuracy considering base itself as (10**30)
 * @notice Implements the functions related to repayments (payments that
 * have to made by the borrower back to the pool)
 * @author Sublime
 */
contract Repayments is Initializable, RepaymentStorage, IRepayment, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address PoolFactory;

    /// @notice Event emitted during current period interest repayment
    /// @param poolID The address of the pool to which interest was paid
    /// @param repayAmount Amount being re-payed by the borrower
    event InterestRepaid(address poolID, uint256 repayAmount);

    /// @notice Event emitted when previous period's interest is repaid fully
    /// @param poolID The address of the pool to which repayment was made 
    event MissedRepaymentRepaid(address poolID); 

    /// @notice Event emitted when previous period's interest is repaid partially
    /// @param poolID The address of the pool to which the partial repayment was made
    event PartialExtensionRepaymentMade(address poolID); 

    /// @notice Event to denote changes in the configurations of the pool factory
    event PoolFactoryUpdated(address poolFactory);
    
    /// @notice Event to denote changes in the configurations of the savings account
    event SavingsAccountUpdated(address savingnsAccount);
    
    /// @notice Event to denote changes in the configurations of the Grace Penalty Rate
    event GracePenalityRateUpdated(uint256 gracePenaltyRate);
    
    /// @notice Event to denote changes in the configurations of the Grace Period Fraction
    event GracePeriodFractionUpdated(uint256 gracePeriodFraction);

  
    /// @notice determines if the pool is active or not based on whether repayments have been started by the 
    ///borrower for this particular pool or not
    /// @dev mapping(address => RepaymentConstants) public repaymentConstants is imported from RepaymentStorage.sol
    /// @param _poolID address of the pool for which we want to test statu
    modifier isPoolInitialized(address _poolID) {
        require(repaymentConstants[_poolID].numberOfTotalRepayments != 0, 'Pool is not Initiliazed');
        _;
    }

    /// @notice modifier used to determine whether the current pool is valid or not
    /// @dev openBorrowPoolRegistry from IPoolFactory interface returns a bool
    modifier onlyValidPool {
        require(poolFactory.openBorrowPoolRegistry(msg.sender), 'Repayments::onlyValidPool - Invalid Pool');
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == poolFactory.owner(), 'Not owner');
        _;
    }

    /// @notice Initializes the contract (similar to a constructor)
    /// @dev Since we cannot use constructors when using OpenZeppelin Upgrades, we use the initialize function 
    ///and the initializer modifier makes sure that this function is called only once
    /// @param _owner The address of the new owner. Different from the deployer of the contract (if required)
    /// @param _poolFactory The address of the pool factory
    /// @param _gracePenaltyRate The penalty rate levied in the grace period
    /// @param _gracePeriodFraction The fraction of repayment interval that will be allowed as grace period
    /// @param _savingsAccount The address of the savings account
    function initialize(
        address _poolFactory,
        uint256 _gracePenaltyRate,
        uint256 _gracePeriodFraction,
        address _savingsAccount
    ) public initializer {
        _updatePoolFactory(_poolFactory);
        _updateGracePenalityRate(_gracePenaltyRate);
        _updateGracePeriodFraction(_gracePeriodFraction);
        _updateSavingsAccount(_savingsAccount);
    }

    function updatePoolFactory(address _poolFactory) public onlyOwner {
        _updatePoolFactory(_poolFactory);
    }

    function _updatePoolFactory(address _poolFactory) internal {
        require(_poolFactory != address(0), '0 address not allowed');
        poolFactory = IPoolFactory(_poolFactory);
        emit PoolFactoryUpdated(_poolFactory);
    }

    function updateGracePeriodFraction(uint256 _gracePeriodFraction) public onlyOwner {
        _updateGracePeriodFraction(_gracePeriodFraction);
    }

    function _updateGracePeriodFraction(uint256 _gracePeriodFraction) internal {
        gracePeriodFraction = _gracePeriodFraction;
        emit GracePeriodFractionUpdated(_gracePeriodFraction);
    }

    function updateGracePenalityRate(uint256 _gracePenaltyRate) public onlyOwner {
        _updateGracePenalityRate(_gracePenaltyRate);
    }

    function _updateGracePenalityRate(uint256 _gracePenaltyRate) internal {
        gracePenaltyRate = _gracePenaltyRate;
        emit GracePenalityRateUpdated(_gracePenaltyRate);
    }

    function updateSavingsAccount(address _savingsAccount) public onlyOwner {
        _updateSavingsAccount(_savingsAccount);
    }

    function _updateSavingsAccount(address _savingsAccount) internal {
        require(_savingsAccount != address(0), '0 address not allowed');
        savingsAccount = _savingsAccount;
        emit SavingsAccountUpdated(_savingsAccount);
    }

    /// @notice For a valid pool, the repayment schedule is being initialized here
    /// @dev Imported from RepaymentStorage.sol repaymentConstants is a mapping(address => RepaymentConstants)
    /// @param numberOfTotalRepayments The total number of repayments that will be required from the borrower
    /// @param repaymentInterval Intervals after which repayment will be due
    /// @param borrowRate The rate at which lending took place
    /// @param loanStartTime The starting time of the loan
    /// @param lentAsset The address of the asset that was lent (basically a ERC20 token address)
    function initializeRepayment(
        uint256 numberOfTotalRepayments,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        address lentAsset
    ) external override onlyValidPool {
        repaymentConstants[msg.sender].gracePenaltyRate = gracePenaltyRate;
        repaymentConstants[msg.sender].gracePeriodFraction = gracePeriodFraction;
        repaymentConstants[msg.sender].numberOfTotalRepayments = numberOfTotalRepayments;
        repaymentConstants[msg.sender].loanDuration = repaymentInterval.mul(numberOfTotalRepayments).mul(10**30);
        repaymentConstants[msg.sender].repaymentInterval = repaymentInterval.mul(10**30);
        repaymentConstants[msg.sender].borrowRate = borrowRate;
        repaymentConstants[msg.sender].loanStartTime = loanStartTime.mul(10**30);
        repaymentConstants[msg.sender].repayAsset = lentAsset;
        repaymentConstants[msg.sender].savingsAccount = savingsAccount;
        repaymentVars[msg.sender].nInstalmentsFullyPaid = 0;
    }

    /*
     * @notice returns the number of repayment intervals that have been repaid,
     * if repayment interval = 10 secs, loan duration covered = 55 secs, repayment intervals covered = 5
     * @param _poolID address of the pool
     * @return scaled interest per second
     */

    function getInterestPerSecond(address _poolID) public view returns (uint256) {
        uint256 _activePrincipal = IPool(_poolID).getTotalSupply();
        uint256 _interestPerSecond = _activePrincipal.mul(repaymentConstants[_poolID].borrowRate).div(yearInSeconds);
        return _interestPerSecond;
    }

    /// @notice This function determines the number of completed instalments
    /// @param _poolID The address of the pool for which we want the completed instalments
    /// @return scaled instalments completed
    function getInstalmentsCompleted(address _poolID) public view returns (uint256) {
        uint256 _repaymentInterval = repaymentConstants[_poolID].repaymentInterval;
        uint256 _loanDurationCovered = repaymentVars[_poolID].loanDurationCovered;
        uint256 _instalmentsCompleted = _loanDurationCovered.div(_repaymentInterval).mul(10**30); // dividing exponents, returns whole number rounded down

        return _instalmentsCompleted;
    }

    /// @notice This function determines the interest that is due for the borrower till the current instalment deadline
    /// @param _poolID The address of the pool for which we want the interest
    /// @return scaled interest due till instalment deadline
    function getInterestDueTillInstalmentDeadline(address _poolID) public view returns (uint256) {
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);
        uint256 _nextInstalmentDeadline = getNextInstalmentDeadline(_poolID);
        uint256 _loanDurationCovered = repaymentVars[_poolID].loanDurationCovered;
        uint256 _interestDueTillInstalmentDeadline =
            (_nextInstalmentDeadline.sub(repaymentConstants[_poolID].loanStartTime).sub(_loanDurationCovered)).mul(_interestPerSecond).div(
                10**30
            );
        return _interestDueTillInstalmentDeadline;
    }


    /// @notice This function determines the timestamp of the next instalment deadline
    /// @param _poolID The address of the pool for which we want the next instalment deadline
    /// @return timestamp before which next instalment ends
    function getNextInstalmentDeadline(address _poolID) public view override returns (uint256) {
        uint256 _instalmentsCompleted = getInstalmentsCompleted(_poolID);
        if (_instalmentsCompleted == repaymentConstants[_poolID].numberOfTotalRepayments) {
            return 0;
        }
        uint256 _loanExtensionPeriod = repaymentVars[_poolID].loanExtensionPeriod;
        uint256 _repaymentInterval = repaymentConstants[_poolID].repaymentInterval;
        uint256 _loanStartTime = repaymentConstants[_poolID].loanStartTime;
        uint256 _nextInstalmentDeadline;

        if (_loanExtensionPeriod > _instalmentsCompleted) {
            _nextInstalmentDeadline = ((_instalmentsCompleted.add(10**30).add(10**30)).mul(_repaymentInterval).div(10**30)).add(
                _loanStartTime
            );
        } else {
            _nextInstalmentDeadline = ((_instalmentsCompleted.add(10**30)).mul(_repaymentInterval).div(10**30)).add(_loanStartTime);
        }
        return _nextInstalmentDeadline;
    }

    /// @notice This function determine the current instalment interval
    /// @param _poolID The address of the pool for which we want the current instalment interval
    /// @return scaled instalment interval
    function getCurrentInstalmentInterval(address _poolID) public view returns (uint256) {
        uint256 _instalmentsCompleted = getInstalmentsCompleted(_poolID);
        return _instalmentsCompleted.add(10**30);
    }

    /// @notice This function determines the current (loan) interval
    /// @dev adding 10**30 to add 1. Considering base itself as (10**30)
    /// @param _poolID The address of the pool for which we want the current loan interval
    /// @return scaled current loan interval
    function getCurrentLoanInterval(address _poolID) external view override returns (uint256) {
        uint256 _loanStartTime = repaymentConstants[_poolID].loanStartTime;
        uint256 _currentTime = block.timestamp.mul(10**30);
        uint256 _repaymentInterval = repaymentConstants[_poolID].repaymentInterval;
        uint256 _currentInterval = ((_currentTime.sub(_loanStartTime)).mul(10**30).div(_repaymentInterval)).add(10**30); 

        return _currentInterval;
    }

    /// @notice Check if grace penalty is applicable or not
    /// @dev (10**30) is included to maintain the accuracy of the arithmetic operations
    /// @param _poolID address of the pool for which we want to inquire if grace penalty is applicable or not
    /// @return boolean value indicating if applicable or not
    function isGracePenaltyApplicable(address _poolID) public view returns (bool) {
        //uint256 _loanStartTime = repaymentConstants[_poolID].loanStartTime;
        uint256 _repaymentInterval = repaymentConstants[_poolID].repaymentInterval;
        uint256 _currentTime = block.timestamp.mul(10**30);
        uint256 _gracePeriodFraction = repaymentConstants[_poolID].gracePeriodFraction;
        uint256 _nextInstalmentDeadline = getNextInstalmentDeadline(_poolID);
        uint256 _gracePeriodDeadline = _nextInstalmentDeadline.add(_gracePeriodFraction.mul(_repaymentInterval).div(10**30));

        require(_currentTime <= _gracePeriodDeadline, 'Borrower has defaulted');

        if (_currentTime <= _nextInstalmentDeadline) return false;
        else return true;
    }

    /// @notice Checks if the borrower has defaulted
    /// @dev (10**30) is included to maintain the accuracy of the arithmetic operations
    /// @param _poolID address of the pool from which borrower borrowed
    /// @return bool indicating whether the borrower has defaulted
    function didBorrowerDefault(address _poolID) public view override returns (bool) {
        uint256 _repaymentInterval = repaymentConstants[_poolID].repaymentInterval;
        uint256 _currentTime = block.timestamp.mul(10**30);
        uint256 _gracePeriodFraction = repaymentConstants[_poolID].gracePeriodFraction;
        uint256 _nextInstalmentDeadline = getNextInstalmentDeadline(_poolID);
        uint256 _gracePeriodDeadline = _nextInstalmentDeadline.add(_gracePeriodFraction.mul(_repaymentInterval).div(10**30));
        if (_currentTime > _gracePeriodDeadline) return true;
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
    /// @notice Determines entire interest remaining to be paid for the loan issued to the borrower
    /// @dev (10**30) is included to maintain the accuracy of the arithmetic operations
    /// @param _poolID address of the pool for which we want to calculate remaining interest
    /// @return interest remaining
    function getInterestLeft(address _poolID) public view returns (uint256) {
        uint256 _interestPerSecond = getInterestPerSecond((_poolID));
        uint256 _loanDurationLeft = repaymentConstants[_poolID].loanDuration.sub(repaymentVars[_poolID].loanDurationCovered);
        uint256 _interestLeft = _interestPerSecond.mul(_loanDurationLeft).div(10**30); // multiplying exponents

        return _interestLeft;
    }
    /// @notice Given there is no loan extension, find the overdue interest after missing the repayment deadline
    /// @dev (10**30) is included to maintain the accuracy of the arithmetic operations
    /// @param _poolID address of the pool
    /// @return interest amount that is overdue
    function getInterestOverdue(address _poolID) public view returns (uint256) {
        require(repaymentVars[_poolID].isLoanExtensionActive == true, 'No overdue');
        uint256 _instalmentsCompleted = getInstalmentsCompleted(_poolID);
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);
        uint256 _interestOverdue =
            (
                (
                    (_instalmentsCompleted.add(10**30)).mul(repaymentConstants[_poolID].repaymentInterval).div(10**30).sub(
                        repaymentVars[_poolID].loanDurationCovered
                    )
                )
            )
                .mul(_interestPerSecond)
                .div(10**30);
        return _interestOverdue;
    }
    
    /// @notice Used to for your overdues, grace penalty and interest
    /// @dev (10**30) is included to maintain the accuracy of the arithmetic operations
    /// @param _poolID address of the pool
    /// @param _amount amount repaid by the borrower
    function repayAmount(address _poolID, uint256 _amount) public payable nonReentrant isPoolInitialized(_poolID) {
        IPool _pool = IPool(_poolID);
        _amount = _amount * 10**30;

        uint256 _loanStatus = _pool.getLoanStatus();
        require(_loanStatus == 1, 'Repayments:repayInterest Pool should be active.');

        uint256 _amountRequired = 0;
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);
        // First pay off the overdue
        if (repaymentVars[_poolID].isLoanExtensionActive == true) {
            uint256 _interestOverdue = getInterestOverdue(_poolID);

            if (_amount >= _interestOverdue) {
                _amount = _amount.sub(_interestOverdue);
                _amountRequired = _amountRequired.add(_interestOverdue);
                repaymentVars[_poolID].isLoanExtensionActive = false; // deactivate loan extension flag
                repaymentVars[_poolID].loanDurationCovered = (getInstalmentsCompleted(_poolID).add(10**30))
                    .mul(repaymentConstants[_poolID].repaymentInterval)
                    .div(10**30);
            } else {
                _amountRequired = _amountRequired.add(_amount);
                repaymentVars[_poolID].loanDurationCovered = repaymentVars[_poolID].loanDurationCovered.add(
                    _amount.mul(10**30).div(_interestPerSecond)
                );
                _amount = 0;
            }
        }

        // Second pay off the interest
        if (_amount != 0) {
            uint256 _interestLeft = getInterestLeft(_poolID);
            bool _isBorrowerLate = isGracePenaltyApplicable(_poolID);

            // adding grace penalty if applicable
            if (_isBorrowerLate) {
                uint256 _penalty =
                    repaymentConstants[_poolID].gracePenaltyRate.mul(getInterestDueTillInstalmentDeadline(_poolID)).div(10**30);
                _amount = _amount.sub(_penalty);
                _amountRequired = _amountRequired.add(_penalty);
            }

            if (_amount < _interestLeft) {
                uint256 _loanDurationCovered = _amount.mul(10**30).div(_interestPerSecond); // dividing exponents
                repaymentVars[_poolID].loanDurationCovered = repaymentVars[_poolID].loanDurationCovered.add(_loanDurationCovered);
                _amountRequired = _amountRequired.add(_amount);
            } else {
                repaymentVars[_poolID].loanDurationCovered = repaymentConstants[_poolID].loanDuration; // full interest repaid
                _amount = _amount.sub(_interestLeft);
                _amountRequired = _amountRequired.add(_interestLeft);
            }
        }

        address _asset = repaymentConstants[_poolID].repayAsset;

        require(_amountRequired != 0, 'Repayments::repayAmount not necessary');
        _amountRequired = _amountRequired.div(10**30);
        repaymentVars[_poolID].repaidAmount = repaymentVars[_poolID].repaidAmount.add(_amountRequired);

        if (_asset == address(0)) {
            require(_amountRequired <= msg.value, 'Repayments::repayAmount amount does not match message value.');
            (bool success, ) = payable(address(_poolID)).call{value: _amountRequired}('');
            require(success, 'Transfer failed');
        } else {
            IERC20(_asset).safeTransferFrom(msg.sender, _poolID, _amountRequired);
        }

        if (_asset == address(0)) {
            if (msg.value > _amountRequired) {
                (bool success, ) = payable(address(msg.sender)).call{value: msg.value.sub(_amountRequired)}('');
                require(success, 'Transfer failed');
            }
        }
    }

    /// @notice Used to pay off the principal of the loan, once the overdues and interests are repaid 
    /// @dev (10**30) is included to maintain the accuracy of the arithmetic operations
    /// @param _poolID address of the pool
    /// @param _amount amount required to pay off the principal
    function repayPrincipal(address payable _poolID, uint256 _amount) public payable nonReentrant isPoolInitialized(_poolID) {
        IPool _pool = IPool(_poolID);
        uint256 _loanStatus = _pool.getLoanStatus();
        require(_loanStatus == 1, 'Repayments:repayPrincipal Pool should be active');

        require(repaymentVars[_poolID].isLoanExtensionActive == false, 'Repayments:repayPrincipal Repayment overdue unpaid');

        require(
            repaymentConstants[_poolID].loanDuration == repaymentVars[_poolID].loanDurationCovered,
            'Repayments:repayPrincipal Unpaid interest'
        );

        uint256 _activePrincipal = _pool.getTotalSupply();
        require(_amount == _activePrincipal, 'Repayments:repayPrincipal Amount should match the principal');

        address _asset = repaymentConstants[_poolID].repayAsset;

        if (_asset == address(0)) {
            require(_amount == msg.value, 'Repayments::repayAmount amount does not match message value.');
            (bool success, ) = _poolID.call{value: _amount}('');
            require(success, 'Transfer failed');
        } else {
            IERC20(_asset).safeTransferFrom(msg.sender, _poolID, _amount);
        }

        IPool(_poolID).closeLoan();
    }

    /*
    function getRepaymentPeriodCovered(address poolID) external view override returns(uint256) {
        return repaymentVars[poolID].repaymentPeriodCovered;
    }
    */

    /// @notice Returns the total amount that has been repaid by the borrower till now
    /// @param poolID address of the pool
    /// @return total amount repaid
    function getTotalRepaidAmount(address _poolID) external view override returns (uint256) {
        return repaymentVars[_poolID].repaidAmount;
    }

    /// @notice This function activates the instalment deadline
    /// @param _poolID address of the pool for which deadline is extended
    /// @param _period period for which the deadline is extended
    function instalmentDeadlineExtended(address _poolID, uint256 _period) external override {
        require(msg.sender == poolFactory.extension(), 'Repayments::repaymentExtended - Invalid caller');

        repaymentVars[_poolID].isLoanExtensionActive = true;
        repaymentVars[_poolID].loanExtensionPeriod = _period;
    }

    /// @notice Returns the loanDurationCovered till now and the interest per second which will help in interest calculation
    /// @param _poolID address of the pool for which we want to calculate interest
    /// @return Loan Duration Covered and the interest per second
    function getInterestCalculationVars(address _poolID) external view override returns (uint256, uint256) {
        uint256 _interestPerSecond = getInterestPerSecond(_poolID);
        return (repaymentVars[_poolID].loanDurationCovered, _interestPerSecond);
    }

    /// @notice Returns the fraction of repayment interval decided as the grace period fraction
    /// @return grace period fraction
    function getGracePeriodFraction() external view override returns (uint256) {
        return gracePeriodFraction;
    }
}