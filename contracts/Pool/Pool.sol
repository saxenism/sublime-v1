// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/IPoolFactory.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IYield.sol";
import "../interfaces/IRepayment.sol";
import "../interfaces/ISavingsAccount.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IExtension.sol";
import "../interfaces/IPoolToken.sol";

// TODO: set modifiers to disallow any transfers directly
contract Pool is Initializable, IPool {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    enum LoanStatus {
        COLLECTION, //denotes collection period
        ACTIVE, // denotes the active loan
        CLOSED, // Loan is repaid and closed
        CANCELLED, // Cancelled by borrower
        DEFAULTED, // Repaymennt defaulted by  borrower
        TERMINATED // Pool terminated by admin
    }

    address PoolFactory;
    IPoolToken poolToken;

    struct LendingDetails {
        uint256 amountWithdrawn;
        uint256 repaymentWithdrawn;
        // bool lastVoteValue; // last vote value is not neccesary as in once cycle user can vote only once
        uint256 lastVoteTime;
        uint256 marginCallEndTime;
        uint256 extraLiquidityShares;
    }

    // Pool constants
    struct PoolConstants {
        address borrower;
        uint256 borrowAmountRequested;
        uint256 minborrowAmountFraction; // min fraction for the loan to continue
        uint256 loanStartTime;
        uint256 matchCollateralRatioEndTime;
        address borrowAsset;
        uint256 collateralRatio;
        uint256 borrowRate;
        uint256 noOfRepaymentIntervals;
        uint256 repaymentInterval;
        address collateralAsset;
        address investedTo; // invest contract
    }

    struct PoolVars {
        uint256 baseLiquidityShares;
        uint256 extraLiquidityShares;
        LoanStatus loanStatus;
        uint256 noOfGracePeriodsTaken;
        uint256 nextDuePeriod;
    }

    // Variables
    // uint256 public liquiditySharesTokenAddress;
    mapping(address => LendingDetails) public lenders;
    PoolConstants public poolConstants;
    PoolVars public poolVars;

    event OpenBorrowPoolCancelled();
    event OpenBorrowPoolTerminated();
    event OpenBorrowPoolClosed();
    event OpenBorrowPoolDefaulted();
    event CollateralAdded(
        address borrower,
        uint256 amount,
        uint256 sharesReceived
    );
    event MarginCallCollateralAdded(
        address borrower,
        address lender,
        uint256 amount,
        uint256 sharesReceived
    );
    // TODO:  Is this declaration correct or the other one
    // event LiquidityWithdrawn(
    //     uint256 amount,
    //     uint256 sharesReceived
    // );
    event CollateralWithdrawn(address user, uint256 amount);
    event LiquiditySupplied(uint256 amountSupplied, address lenderAddress);
    event AmountBorrowed(address borrower, uint256 amount);
    event LiquidityWithdrawn(uint256 amount, address lenderAddress);
    event CollateralCalled(address lenderAddress);
    event LoanDefaulted();
    event LenderLiquidated(
        address liquidator,
        address lender,
        uint256 _tokenReceived
    );
    event PoolLiquidated(address liquidator);


    modifier OnlyBorrower(address _user) {
        require(
            _user == poolConstants.borrower,
            "1"
        );
        _;
    }

    modifier isLender(address _lender) {
        require(
            poolToken.balanceOf(_lender) != 0,
            "2"
        );
        _;
    }

    modifier onlyOwner {
        require(
            msg.sender == IPoolFactory(PoolFactory).owner(),
            "3"
        );
        _;
    }

    modifier isPoolActive {
        require(
            poolVars.loanStatus == LoanStatus.ACTIVE,
            "4"
        );
        _;
    }

    modifier onlyExtension {
        require(msg.sender == IPoolFactory(PoolFactory).extension(), "5");
        _;
    }

    function initialize(
        uint256 _borrowAmountRequested,
        uint256 _minborrowAmountFraction, // denomination is 10^8
        address _borrower,
        address _borrowAsset,
        address _collateralAsset,
        uint256 _collateralRatio,
        uint256 _borrowRate,
        uint256 _repaymentInterval,
        uint256 _noOfRepaymentIntervals,
        address _investedTo,
        uint256 _collateralAmount,
        bool _transferFromSavingsAccount
    ) external initializer {
        uint256 _collectionPeriod = IPoolFactory(msg.sender).collectionPeriod();
        poolConstants = PoolConstants(
            _borrower,
            _borrowAmountRequested,
            _minborrowAmountFraction,
            block.timestamp.add(_collectionPeriod),
            block.timestamp.add(_collectionPeriod).add(
                IPoolFactory(msg.sender).matchCollateralRatioInterval()
            ),
            _borrowAsset,
            _collateralRatio,
            _borrowRate,
            _noOfRepaymentIntervals,
            _repaymentInterval,
            _collateralAsset,
            _investedTo
        );

        PoolFactory = msg.sender;

        depositCollateral(_collateralAmount, _transferFromSavingsAccount);
    }

    function setPoolToken(address _poolToken) external override {
        require(msg.sender == PoolFactory, "6");
        poolToken = IPoolToken(_poolToken);
    }

    function depositCollateral(
        uint256 _amount,
        bool _transferFromSavingsAccount
    ) public payable override {
        require(_amount != 0, "7");

        uint256 _sharesReceived =
            _depositToSavingsAccount(
                _transferFromSavingsAccount,
                poolConstants.collateralAsset,
                _amount,
                poolConstants.investedTo,
                address(this),
                msg.sender
            );

        poolVars.baseLiquidityShares = poolVars.baseLiquidityShares.add(
            _sharesReceived
        );
        emit CollateralAdded(msg.sender, _amount, _sharesReceived);
    }

    function _depositToSavingsAccount(
        bool _transferFromSavingsAccount,
        address _asset,
        uint256 _amount,
        address _investedTo,
        address _depositTo,
        address _depositFrom
    ) internal returns (uint256) {
        ISavingsAccount _savingAccount =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        uint256 _sharesReceived;
        if (!_transferFromSavingsAccount) {
            if (_asset == address(0)) {
                require(
                    msg.value == _amount,
                    "8"
                );
                _sharesReceived = _savingAccount.deposit{value: msg.value}(
                    _amount,
                    _asset,
                    _investedTo
                );
            } else {
                IERC20(_asset).safeTransferFrom(
                    _depositFrom,
                    _depositTo,
                    _amount
                );
                IERC20(_asset).safeApprove(address(_savingAccount), _amount);
                _sharesReceived = _savingAccount.deposit(
                    _amount,
                    _asset,
                    _investedTo
                );
            }
        } else {
            uint256 _liquidityshare =
                IYield(_investedTo).getTokensForShares(_amount, _asset);
            _sharesReceived = _savingAccount.transferFrom(
                _asset,
                _depositFrom,
                _depositTo,
                _investedTo,
                _liquidityshare
            );
        }
        return _sharesReceived;
    }

    function addCollateralInMarginCall(
        address _lender,
        uint256 _amount,
        bool _transferFromSavingsAccount
    ) external payable override {
        
        require(poolVars.loanStatus == LoanStatus.ACTIVE,
                "9");

        require(lenders[_lender].marginCallEndTime >= block.timestamp,
                "10");

        require(_amount != 0,
                "11");

        uint256 _sharesReceived =
            _depositToSavingsAccount(
                _transferFromSavingsAccount,
                poolConstants.collateralAsset,
                _amount,
                poolConstants.investedTo,
                address(this),
                msg.sender
            );

        poolVars.extraLiquidityShares = poolVars.extraLiquidityShares.add(
            _sharesReceived
        );

        lenders[_lender].extraLiquidityShares = lenders[_lender]
            .extraLiquidityShares
            .add(_sharesReceived);

        if(getCurrentCollateralRatio(_lender) >= poolConstants.collateralRatio) {
            delete lenders[_lender].marginCallEndTime;
        }

        emit MarginCallCollateralAdded(
            msg.sender,
            _lender,
            _amount,
            _sharesReceived
        );
    }

    function withdrawBorrowedAmount() external override OnlyBorrower(msg.sender) {
        LoanStatus _poolStatus = poolVars.loanStatus;
        if (
            _poolStatus == LoanStatus.COLLECTION &&
            poolConstants.loanStartTime < block.timestamp
        ) {
            if (
                poolToken.totalSupply() <
                poolConstants
                    .borrowAmountRequested
                    .mul(poolConstants.minborrowAmountFraction)
                    .div(100)
            ) {
                poolVars.loanStatus = LoanStatus.CANCELLED;
                withdrawAllCollateral();
                return;
            }

            poolVars.loanStatus = LoanStatus.ACTIVE;
        }
        require(
            (poolVars.loanStatus == LoanStatus.ACTIVE) &&
                (poolConstants.matchCollateralRatioEndTime != 0),
            "12"
        );
        uint256 _currentCollateralRatio = getCurrentCollateralRatio();
        require(
            _currentCollateralRatio >
                poolConstants.collateralRatio.sub(
                    IPoolFactory(PoolFactory).collateralVolatilityThreshold()
                ),
            "13"
        );
        uint256 _noOfRepaymentIntervals = poolConstants.noOfRepaymentIntervals;
        uint256 _repaymentInterval = poolConstants.repaymentInterval;
        IPoolFactory _poolFactory = IPoolFactory(PoolFactory);
        IRepayment(_poolFactory.repaymentImpl()).initializeRepayment(_noOfRepaymentIntervals, _repaymentInterval, poolConstants.borrowRate, poolConstants.loanStartTime);
        IExtension(_poolFactory.extension()).initializePoolExtension(_repaymentInterval);
        uint256 _tokensLent = poolToken.totalSupply();
        IERC20(poolConstants.borrowAsset).transfer(
            poolConstants.borrower,
            _tokensLent
        );

        delete poolConstants.matchCollateralRatioEndTime;
        emit AmountBorrowed(msg.sender, _tokensLent);
    }


    function withdrawAllCollateral() internal OnlyBorrower(msg.sender) {
        LoanStatus _status = poolVars.loanStatus;
        require(
            _status == LoanStatus.CLOSED || _status == LoanStatus.CANCELLED,
            "14"
        );

        uint256 _collateralShares =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);

        uint256 _sharesReceived =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount())
                .transfer(
                poolConstants.collateralAsset,
                msg.sender,
                poolConstants.investedTo,
                _collateralShares
            );
        emit CollateralWithdrawn(msg.sender, _sharesReceived);
        delete poolVars.baseLiquidityShares;
        delete poolVars.extraLiquidityShares;
    }

    function lend(address _lender, uint256 _amountLent) external payable {
        require(
            poolVars.loanStatus == LoanStatus.COLLECTION,
            "15"
        );
        require(
            block.timestamp < poolConstants.loanStartTime,
            "16"
        );
        uint256 _amount = _amountLent;
        uint256 _borrowAmountNeeded = poolConstants.borrowAmountRequested;
        if (_amountLent.add(poolToken.totalSupply()) > _borrowAmountNeeded) {
            _amount = _borrowAmountNeeded.sub(poolToken.totalSupply());
        }

        address _borrowToken = poolConstants.borrowAsset;
        if (_borrowToken == address(0)) {
            require(
                _amountLent == msg.value,
                "17"
            );
            if (_amount != _amountLent) {
                msg.sender.transfer(_amountLent.sub(_amount));
            }
        } else {
            IERC20(_borrowToken).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }
        poolToken.mint(_lender, _amount);
        emit LiquiditySupplied(_amount, _lender);
    }

    function beforeTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public override {
        require(msg.sender == address(poolToken));
        require(
            lenders[_from].marginCallEndTime != 0,
            "18"
        );
        require(
            lenders[_to].marginCallEndTime != 0,
            "19"
        );

        //Withdraw repayments for user
        _withdrawRepayment(_from, true);
        _withdrawRepayment(_to, true);

        //transfer extra liquidity shares
        uint256 _liquidityShare = lenders[_from].extraLiquidityShares;
        if (_liquidityShare == 0) return;

        uint256 toTransfer = _liquidityShare;
        if (_amount != poolToken.balanceOf(_from)) {
            toTransfer = (_amount.mul(_liquidityShare)).div(
                poolToken.balanceOf(_from)
            );
        }

        lenders[_from].extraLiquidityShares = lenders[_from]
            .extraLiquidityShares
            .sub(toTransfer);

        lenders[_to].extraLiquidityShares = lenders[_to]
            .extraLiquidityShares
            .add(toTransfer);
    }

    function cancelOpenBorrowPool() external OnlyBorrower(msg.sender) {
        require(
            block.timestamp < poolConstants.matchCollateralRatioEndTime,
            "20"
        );
        poolVars.loanStatus = LoanStatus.CANCELLED;
        IExtension(IPoolFactory(PoolFactory).extension()).closePoolExtension();
        withdrawAllCollateral();
        poolToken.pause();
        emit OpenBorrowPoolCancelled();
    }

    function terminateOpenBorrowPool() external onlyOwner {
        LoanStatus _poolStatus = poolVars.loanStatus;
        require(
            _poolStatus == LoanStatus.ACTIVE ||
                _poolStatus == LoanStatus.COLLECTION,
            "21"
        );

        uint256 _collateralShares =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);
        ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount()).transfer(
            poolConstants.collateralAsset,
            IPoolFactory(PoolFactory).owner(),
            poolConstants.investedTo,
            _collateralShares
        );
        poolToken.pause();
        poolVars.loanStatus = LoanStatus.TERMINATED;
        IExtension(IPoolFactory(PoolFactory).extension()).closePoolExtension();
        emit OpenBorrowPoolTerminated();
    }

    function closeLoan() external OnlyBorrower(msg.sender) {
        require(
            poolVars.loanStatus == LoanStatus.ACTIVE,
            "22"
        );
        require(
            poolVars.nextDuePeriod == 0,
            "23"
        );
        poolVars.loanStatus = LoanStatus.CLOSED;
        IExtension(IPoolFactory(PoolFactory).extension()).closePoolExtension();
        withdrawAllCollateral();
        poolToken.pause();
        emit OpenBorrowPoolClosed();
    }

    // Note - Only when closed, cancelled or terminated, lender can withdraw
    //burns all shares and returns total remaining repayments along with provided liquidity
    function withdrawLiquidity() external isLender(msg.sender) {
        LoanStatus _loanStatus = poolVars.loanStatus;
        require(
            _loanStatus == LoanStatus.CLOSED ||
                _loanStatus == LoanStatus.CANCELLED ||
                _loanStatus == LoanStatus.DEFAULTED,
            "24"
        );

        //get total repayments collected as per loan status (for closed, it returns 0)
        uint256 _due = calculateRepaymentWithdrawable(msg.sender);

        //gets amount through liquidity shares
        uint256 _balance = poolToken.balanceOf(msg.sender);
        poolToken.burn(msg.sender, _balance);

        if (_loanStatus == LoanStatus.DEFAULTED) {
            uint256 _totalAsset;
            if (poolConstants.borrowAsset != address(0)) {
                _totalAsset = IERC20(poolConstants.borrowAsset).balanceOf(
                    address(this)
                );
            } else {
                _totalAsset = address(this).balance;
            }

            //assuming their will be no tokens in pool in any case except liquidation (to be checked) or we should store the amount in liquidate()
            _balance = _balance.mul(_totalAsset).div(poolToken.totalSupply());
        }

        _due = _balance.add(_due);

        lenders[msg.sender].amountWithdrawn = lenders[msg.sender]
            .amountWithdrawn
            .add(_due);

        //transfer repayment
        //TODO: to decide which contract will contain this
        _withdrawRepayment(msg.sender, true);
        //to add transfer if not included in above (can be transferred with liquidity)

        //transfer liquidity provided
        if (poolConstants.borrowAsset != address(0)) {
            IERC20(poolConstants.borrowAsset).transfer(msg.sender, _balance);
        } else {
            msg.sender.transfer(_balance);
        }
        // TODO: Something wrong in the below event. Please have a look
        emit LiquidityWithdrawn(_due, msg.sender);
    }


    /**
     * @dev This function is executed by lender to exercise margin call
     * @dev It will revert in case collateral ratio is not below expected value
     * or the lender has already called it.
     */

    function requestMarginCall() external isPoolActive isLender(msg.sender) {
        require(
            lenders[msg.sender].marginCallEndTime < block.timestamp,
            "25"
        );

        require(
            poolConstants.collateralRatio >
                getCurrentCollateralRatio(msg.sender).add(
                    IPoolFactory(PoolFactory).collateralVolatilityThreshold()
                ),
            "26"
        );

        lenders[msg.sender].marginCallEndTime = block.timestamp.add(
            IPoolFactory(PoolFactory).marginCallDuration()
        );

        emit CollateralCalled(msg.sender);
    }

    // function transferRepayImpl(address repayment) external onlyOwner {}

    // function transferLenderImpl(address lenderImpl) external onlyOwner {
    //     require(lenderImpl != address(0), "Borrower: Lender address");
    //     _lender = lenderImpl;
    // }

    // event PoolLiquidated(bytes32 poolHash, address liquidator, uint256 amount);
    // //todo: add more details here
    // event Liquidated(address liquidator, address lender);

    // function amountPerPeriod() public view returns (uint256) {}

    function interestTillNow(uint256 _balance, uint256 _interestPerPeriod)
        public
        view
        returns (uint256)
    {
        uint256 _totalSupply = poolToken.totalSupply();
        

        IPoolFactory _poolFactory = IPoolFactory(PoolFactory);

        (uint256 _repaymentPeriodCovered, uint256 _repaymentOverdue) = IRepayment(_poolFactory.repaymentImpl()).getInterestCalculationVars(address(this));

        uint256 _interestAccruedThisPeriod = ((block.timestamp).sub(_repaymentPeriodCovered)).mul(_interestPerPeriod);

        uint256 _totalInterest = (_interestAccruedThisPeriod.add(_repaymentOverdue)).mul(_balance).div(_totalSupply);
        return _totalInterest;
    }

    function calculateCollateralRatio(
        uint256 _interestPerPeriod,
        uint256 _balance,
        uint256 _liquidityShares
    ) public returns (uint256) {

        uint256 _interest = interestTillNow(_balance, _interestPerPeriod);

        address _collateralAsset = poolConstants.collateralAsset;

        uint256 _ratioOfPrices =IPriceOracle(IPoolFactory(PoolFactory).priceOracle()).getLatestPrice(_collateralAsset, poolConstants.borrowAsset);

        uint256 _currentCollateralTokens =IYield(poolConstants.investedTo).getTokensForShares(_liquidityShares,_collateralAsset);

        uint256 _ratio =(_currentCollateralTokens.mul(_ratioOfPrices).div(100000000)).div(_balance.add(_interest));

        return (_ratio);
    }

    function getCurrentCollateralRatio() public returns (uint256) {
        uint256 _liquidityShares =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);
        return (
            calculateCollateralRatio(
                interestPerPeriod(poolToken.totalSupply()),
                poolToken.totalSupply(),
                _liquidityShares
            )
        );
    }

    function getCurrentCollateralRatio(address _lender)
        public
        returns (uint256 _ratio)
    {
        uint256 _balanceOfLender = poolToken.balanceOf(_lender);
        uint256 _liquidityShares =
            (
                poolVars.baseLiquidityShares.mul(_balanceOfLender).div(
                    poolToken.totalSupply()
                )
            )
                .add(lenders[_lender].extraLiquidityShares);
        return (
            calculateCollateralRatio(
                interestPerPeriod(poolToken.balanceOf(_lender)),
                _balanceOfLender,
                _liquidityShares
            )
        );
    }

    function liquidatePool(
        bool _transferToSavingsAccount,
        bool _recieveLiquidityShare
    ) external payable {
        LoanStatus _currentPoolStatus;
        if (poolVars.loanStatus != LoanStatus.DEFAULTED) {
            _currentPoolStatus = checkRepayment();
        }
        require(
            _currentPoolStatus == LoanStatus.DEFAULTED,
            "Pool::liquidatePool - No reason to liquidate the pool"
        );
        ISavingsAccount _savingAccount =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());

        address _collateralAsset = poolConstants.collateralAsset;
        address _borrowAsset = poolConstants.borrowAsset;
        uint256 _collateralLiquidityShare =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);
        uint256 _correspondingBorrowTokens =
            correspondingBorrowTokens(_collateralLiquidityShare);

        if (_borrowAsset == address(0)) {
            if (msg.value < _correspondingBorrowTokens) {
                revert("Pool::liquidatePool - Not enough tokens");
            }
        } else {
            IERC20(_borrowAsset).transferFrom(
                msg.sender,
                address(this),
                _correspondingBorrowTokens
            );
        }
        address _investedTo = poolConstants.investedTo;

        if (_transferToSavingsAccount) {
            _savingAccount.transfer(
                _collateralAsset,
                msg.sender,
                _investedTo,
                _collateralLiquidityShare
            );
        } else {
            uint256 _collateralTokens =
                IYield(_investedTo).getTokensForShares(
                    _collateralLiquidityShare,
                    _collateralAsset
                );
            uint256 _amountReceived =
                _savingAccount.withdraw(
                    payable(address(this)),
                    _collateralTokens,
                    _collateralAsset,
                    _investedTo,
                    _recieveLiquidityShare
                );
            if (_recieveLiquidityShare) {
                address _addressOfTheLiquidityToken =
                    IYield(_investedTo).liquidityToken(_collateralAsset);
                IERC20(_addressOfTheLiquidityToken).transfer(
                    msg.sender,
                    _amountReceived
                );
            } else {
                if (_collateralAsset == address(0)) {
                    msg.sender.transfer(_amountReceived);
                } else {
                    IERC20(_collateralAsset).transfer(
                        msg.sender,
                        _amountReceived
                    );
                }
            }
        }
        emit PoolLiquidated(msg.sender);
    }

    function liquidateLender(
        address lender,
        bool _transferToSavingsAccount,
        bool _recieveLiquidityShare
    ) public payable {
        //avoid stack too deep
        {
            require(
                (poolVars.loanStatus == LoanStatus.ACTIVE) &&
                    (block.timestamp > poolConstants.matchCollateralRatioEndTime),
                "27"
            );
            uint256 _marginCallEndTime = lenders[lender].marginCallEndTime;
            require(_marginCallEndTime != 0, "No margin call has been called.");
            require(
                _marginCallEndTime < block.timestamp,
                "28"
            );

            require(
                poolConstants.collateralRatio.sub(
                    IPoolFactory(PoolFactory).collateralVolatilityThreshold()
                ) > getCurrentCollateralRatio(lender),
                "29"
            );
            require(
                poolToken.balanceOf(lender) != 0,
                "30"
            );
        }
        ISavingsAccount _savingAccount =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());

        address _collateralAsset = poolConstants.collateralAsset;
        address _investedTo = poolConstants.investedTo;
        uint256 _lenderBalance = poolToken.balanceOf(lender);
        uint256 _collateralLiquidityShare =
            (
                (poolVars.baseLiquidityShares.mul(_lenderBalance)).div(
                    poolToken.totalSupply()
                )
            )
                .add(lenders[lender].extraLiquidityShares);
        uint256 _collateralTokens =
            IYield(_investedTo).getTokensForShares(
                _collateralLiquidityShare,
                _collateralAsset
            );

        {
            uint256 _correspondingBorrowTokens =
                correspondingBorrowTokens(_collateralLiquidityShare);
            address _borrowAsset = poolConstants.borrowAsset;
            uint256 _sharesReceived;
            if (_borrowAsset == address(0)) {
                require(msg.value < _correspondingBorrowTokens, "31");
                _sharesReceived = _savingAccount.deposit{value: msg.value}(
                    msg.value,
                    _borrowAsset,
                    _investedTo
                );
            } else {
                IERC20(_borrowAsset).transferFrom(
                    msg.sender,
                    address(this),
                    _correspondingBorrowTokens
                );
                _sharesReceived = _savingAccount.deposit(
                    _correspondingBorrowTokens,
                    _borrowAsset,
                    _investedTo
                );
            }

            _withdrawRepayment(lender, true);
            _savingAccount.transfer(
                _borrowAsset,
                lender,
                poolConstants.investedTo,
                _sharesReceived
            );
        }

        uint256 _amountReceived;
        if (_transferToSavingsAccount) {
            _amountReceived = _savingAccount.transfer(
                _collateralAsset,
                msg.sender,
                poolConstants.investedTo,
                _collateralLiquidityShare
            );
        } else {
            _amountReceived = _savingAccount.withdraw(
                payable(address(this)),
                _collateralTokens,
                _collateralAsset,
                _investedTo,
                _recieveLiquidityShare
            );
            if (_recieveLiquidityShare) {
                address _liquidityShareAddress =
                    IYield(_investedTo).liquidityToken(_collateralAsset);
                IERC20(_liquidityShareAddress).transfer(
                    msg.sender,
                    _amountReceived
                );
            } else {
                if (_collateralAsset == address(0)) {
                    msg.sender.transfer(_amountReceived);
                } else {
                    IERC20(_collateralAsset).transfer(
                        msg.sender,
                        _amountReceived
                    );
                }
            }
        }
        poolToken.burn(lender, _lenderBalance);
        delete lenders[lender];
        emit LenderLiquidated(msg.sender, lender, _amountReceived);
    }


    function correspondingBorrowTokens(uint256 _liquidityShares)
        public
        returns (uint256)
    {
        IPoolFactory _poolFactory = IPoolFactory(PoolFactory);
        uint256 _collateralTokens =
            IYield(poolConstants.investedTo).getTokensForShares(
                _liquidityShares,
                poolConstants.collateralAsset
            );

        return
            (
                _collateralTokens
                    .mul(
                    IPriceOracle(_poolFactory.priceOracle()).getLatestPrice(
                        poolConstants.borrowAsset,
                        poolConstants.collateralAsset
                    )
                )
                    .div(10**8)
            )
                .mul(
                uint256(10**8).sub(_poolFactory.liquidatorRewardFraction())
            )
                .div(10**8);
    }

    function checkRepayment() public returns (LoanStatus) {
        uint256 _gracePeriodPenaltyFraction =
            IPoolFactory(PoolFactory).gracePeriodPenaltyFraction();
        if (
            block.timestamp > getNextDueTime().add(
                _gracePeriodPenaltyFraction.mul(poolConstants.repaymentInterval)
            )
        ) {
            poolVars.loanStatus = LoanStatus.DEFAULTED;
            IExtension(IPoolFactory(PoolFactory).extension()).closePoolExtension();
            return (LoanStatus.DEFAULTED);
        }
        return (poolVars.loanStatus);
    }


    function getNextDueTimeIfBorrower(address _borrower) override view external OnlyBorrower(_borrower) returns(uint256) {
        return getNextDueTime();
    }

    function getNextDueTime() public view returns(uint256) {
        return (poolVars.nextDuePeriod.mul(poolConstants.repaymentInterval)).add(poolConstants.loanStartTime);
    }

    

    function interestPerSecond(uint256 _principle)
        public
        view
        returns (uint256)
    {
        uint256 _interest =
            ((_principle).mul(poolConstants.borrowRate)).div(365 days);
        return _interest;
    }

    function interestPerPeriod(uint256 _balance) public view returns (uint256) {
        return (
            interestPerSecond(_balance).mul(poolConstants.repaymentInterval)
        );
    }

    function calculateCurrentPeriod() public view returns (uint256) {
        uint256 _currentPeriod =
            (
                block.timestamp.sub(
                    poolConstants.loanStartTime,
                    "34"
                )
            )
                .div(poolConstants.repaymentInterval);
        return _currentPeriod;
    }

    function calculateRepaymentWithdrawable(address _lender)
        internal
        view
        returns (uint256)
    {
        uint256 _totalRepaidAmount =
            IRepayment(IPoolFactory(PoolFactory).repaymentImpl())
                .getTotalRepaidAmount(address(this));

        uint256 _amountWithdrawable =
            (
                poolToken.balanceOf(_lender).mul(_totalRepaidAmount).div(
                    poolToken.totalSupply()
                )
            )
                .sub(lenders[_lender].repaymentWithdrawn);

        return _amountWithdrawable;
    }

    // Withdraw Repayment, Also all the extra state variables are added here only for the review

    function withdrawRepayment(bool _withdrawToSavingsAccount)
        external
        isLender(msg.sender)
    {
        _withdrawRepayment(msg.sender, _withdrawToSavingsAccount);
    }

    function _withdrawRepayment(address _lender, bool _withdrawToSavingsAccount)
        internal
    {
        uint256 _amountToWithdraw = calculateRepaymentWithdrawable(_lender);
        uint256 _sharesReceived;
        address _investedTo = address(0); //add defaultStrategy
        if (_withdrawToSavingsAccount) {
            ISavingsAccount _savingsAccount =
                ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());

            if (poolConstants.borrowAsset == address(0)) {
                // add check to see if _amount is available or not
                _sharesReceived = _savingsAccount.depositTo{
                    value: _amountToWithdraw
                }(
                    _amountToWithdraw,
                    poolConstants.borrowAsset,
                    _investedTo,
                    _lender
                ); // deposit from pool to lender
            } else {
                _sharesReceived = _savingsAccount.depositTo(
                    _amountToWithdraw,
                    poolConstants.borrowAsset,
                    _investedTo,
                    _lender
                );
            }
        } else {
            if (poolConstants.borrowAsset == address(0)) {
                // should conisder transfer instead
                payable(_lender).transfer(_amountToWithdraw);
            } else {
                IERC20(poolConstants.borrowAsset).transferFrom(
                    address(this),
                    _lender,
                    _amountToWithdraw
                );
            }
        }
        lenders[_lender].repaymentWithdrawn = lenders[_lender]
            .repaymentWithdrawn
            .add(_amountToWithdraw);
    }

    function getNextDuePeriod() external view override returns(uint256) {
        return poolVars.nextDuePeriod;
    }

    function getMarginCallEndTime(address _lender) external view override returns(uint256) {
        return lenders[_lender].marginCallEndTime;
    }





    // Withdraw Repayment, Also all the extra state variables are added here only for the review

    // function withdrawRepayment() external payable {}

    // function transferTokensRepayments(
    //     uint256 amount,
    //     address from,
    //     address to
    // ) internal {}

    // function calculateWithdrawRepayment(address lender)
    //     public
    //     view
    //     returns (uint256)
    // {
    //     if (poolVars.loanStatus == LoanStatus.CANCELLED) return 0;
    // }

    // function calculatewithdrawRepayment(address lender)
    //     public
    //     view
    //     returns (uint256)
    // {}

    // function _withdrawRepayment(address lender) internal {}
    function getTotalSupply() override public view returns (uint256) {
        return poolToken.totalSupply();
    }

    

    function getBalanceDetails(address _lender) override public view returns(uint256, uint256) {
        IPoolToken _poolToken = poolToken;
        return (_poolToken.balanceOf(_lender), _poolToken.totalSupply());
    }

    function grantExtension() override external onlyExtension returns(uint256) {
        uint256 _nextDuePeriod = poolVars.nextDuePeriod.add(1);
        poolVars.nextDuePeriod = _nextDuePeriod;
        return _nextDuePeriod;
    }

    function getLoanStatus() public view override returns (uint256) {
        return uint256(poolVars.loanStatus);
    }

    receive() external payable {
        require(
            msg.sender == IPoolFactory(PoolFactory).savingsAccount(),
            "35"
        );
    }

    // function getLenderCurrentCollateralRatio(address lender) public view returns(uint256){

    // }

    // function addCollateralMarginCall(address lender,uint256 amount) external payable
    // {
    //     require(loanStatus == LoanStatus.ACTIVE, "Pool::deposit - Loan needs to be in Active stage to deposit"); // update loan status during next interaction after collection period
    //     require(lenders[lender].marginCallEndTime > block.timestamp, "Pool::deposit - Can't Add after time is completed");
    //     _deposit(_amount);
    // }
}
