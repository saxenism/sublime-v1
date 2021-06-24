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

    event InterestRepaid(address poolID, uint256 repayAmount); // Made during current period interest repayment
    event MissedRepaymentRepaid(address poolID); // Previous period's interest is repaid fully
    event PartialExtensionRepaymentMade(address poolID); // Previous period's interest is repaid partially

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

    function calculateRepayAmount(address poolID)
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

    function repayInterest(address _poolID, uint256 _amount) public payable isPoolInitialized {

        IPool _pool = IPool(_poolID);
        uint256 _loanStatus = _pool.getLoanStatus();
        require(_loanStatus == 1,
                "Repayments:repayInterest Pool should be active.");

        require(repaymentDetails[_poolID].repaymentOverdue == 0,
                "Repayments:repayInterest Repayment overdue unpaid.");

        uint256 _activePrincipal = _pool.getTotalSupply();

        uint256 _interestPerSecond = _activePrincipal
                                     .mul(repaymentDetails[_poolID].borrowRate)
                                     .div(yearInSeconds);

        uint256 _loanDurationLeft = repaymentDetails[_poolID].loanDuration
                                    .sub(repaymentDetails[_poolID].loanDurationCovered);

        uint256 _interestLeft = _interestPerSecond.mul(_loanDurationLeft).div(10**8);

        require(_amount <= _interestLeft,
                "Repayments:repayInterest cannot repay more interest than due.");

        uint256 _loanDurationCovered = _amount.div(_interestPerSecond).div(10**8);

        repaymentDetails[_poolID].loanDurationCovered = repaymentDetails[_poolID].loanDurationCovered
                                                        .add(_loanDurationCovered);

        address _asset = repaymentDetails[_poolID].repayAsset;

        if (_asset == address(0)) {
            require(_amount == msg.value,
                    "Repayments::repayAmount amount does not match message value.");
        }
        // Note: If ether is sent unnecessarily then that will be sent to savingsAccount
        ISavingsAccount(savingsAccount).depositTo{value: msg.value}(_amount, _asset, address(0), _poolID);
    }

    function repayPrincipal(address payable _poolID, uint256 _amount) public payable isPoolInitialized {

        IPool _pool = IPool(_poolID);
        uint256 _loanStatus = _pool.getLoanStatus();
        require(_loanStatus == 1,
                "Repayments:repayPrincipal Pool should be active");

        require(repaymentDetails[_poolID].repaymentOverdue == 0,
                "Repayments:repayPrincipal Repayment overdue unpaid");

        require(repaymentDetails[_poolID].loanDuration == repaymentDetails[_poolID].loanDurationCovered,
                "Repayments:repayPrincipal Unpaid interest");

        uint256 _activePrincipal = _pool.getTotalSupply();
        require(_amount == _activePrincipal,
                "Repayments:repayPrincipal Amount should match the principal");

        address _asset = repaymentDetails[_poolID].repayAsset;

        if (_asset == address(0)) {
            require(_amount == msg.value,
                    "Repayments::repayAmount amount does not match message value.");
            _poolID.transfer(_amount);
        } 
        else {
            IERC20(_asset).transferFrom(msg.sender, _poolID, _amount);
        }

        IPool(_poolID).closeLoan();
    }

    function repayOverdue(address _poolID, uint256 _amount) public payable isPoolInitialized {

        IPool _pool = IPool(_poolID);
        uint256 _loanStatus = _pool.getLoanStatus();
        require(_loanStatus == 1,
                "Repayments:repayPrincipal Pool should be active");
        uint256 _repaymentOverdue = repaymentDetails[_poolID].repaymentOverdue;

        require(_repaymentOverdue != 0,
                "Repayments:repayOverdue there is no overdue");

        require(_repaymentOverdue >= _amount,
                "Repayments:repayOverdue amount must not be greater than overdue");

        repaymentDetails[_poolID].repaymentOverdue = _repaymentOverdue - _amount;

        address _asset = repaymentDetails[_poolID].repayAsset;

        if (_asset == address(0)) {
            require(_amount == msg.value,
                    "Repayments::repayAmount amount does not match message value.");
        }
        // Note: If ether is sent unnecessarily then that will be sent to savingsAccount
        ISavingsAccount(savingsAccount).depositTo{value: _amount}(_amount, _asset, address(0), _poolID);
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
