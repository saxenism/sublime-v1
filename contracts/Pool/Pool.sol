// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/IPoolFactory.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IYield.sol";
import "../interfaces/IRepayment.sol";
import "../interfaces/ISavingsAccount.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IExtension.sol";
import "../interfaces/IPoolToken.sol";

contract Pool is Initializable, IPool, ReentrancyGuard {
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
        uint256 principalWithdrawn;
        uint256 interestWithdrawn;
        uint256 lastVoteTime;
        uint256 marginCallEndTime;
        uint256 extraLiquidityShares;
    }

    // Pool constants
    struct PoolConstants {
        address borrower;
        uint256 borrowAmountRequested;
        uint256 minborrowAmount;
        uint256 loanStartTime;
        uint256 loanWithdrawalDeadline;
        address borrowAsset;
        uint256 idealCollateralRatio;
        uint256 borrowRate;
        uint256 noOfRepaymentIntervals;
        uint256 repaymentInterval;
        address collateralAsset;
        address poolSavingsStrategy; // invest contract
    }

    struct PoolVars {
        uint256 baseLiquidityShares;
        uint256 extraLiquidityShares;
        LoanStatus loanStatus;
        uint256 noOfGracePeriodsTaken;
        uint256 nextDuePeriod;
    }

    mapping(address => LendingDetails) public lenders;
    PoolConstants public poolConstants;
    PoolVars public poolVars;

    /// @notice Emitted when pool is cancelled either on borrower request or insufficient funds collected
    event OpenBorrowPoolCancelled();

    /// @notice Emitted when pool is terminated by admin
    event OpenBorrowPoolTerminated();

    /// @notice Emitted when pool is closed after repayments are complete
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
    event CollateralWithdrawn(address borrower, uint256 amount);
    event LiquiditySupplied(uint256 amountSupplied, address lenderAddress);
    event AmountBorrowed(uint256 amount);
    event LiquidityWithdrawn(uint256 amount, address lenderAddress);
    event MarginCalled(address lenderAddress);
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
        uint256 _minborrowAmount,
        address _borrower,
        address _borrowAsset,
        address _collateralAsset,
        uint256 _idealCollateralRatio,
        uint256 _borrowRate,
        uint256 _repaymentInterval,
        uint256 _noOfRepaymentIntervals,
        address _poolSavingsStrategy,
        uint256 _collateralAmount,
        bool _transferFromSavingsAccount,
        uint256 _loanWithdrawalDuration,
        uint256 _collectionPeriod
    ) external payable initializer {
        PoolFactory = msg.sender;
        poolConstants.borrowAsset = _borrowAsset;
        poolConstants.idealCollateralRatio = _idealCollateralRatio;
        poolConstants.collateralAsset = _collateralAsset;
        poolConstants.poolSavingsStrategy = _poolSavingsStrategy;
        poolConstants.borrowAmountRequested = _borrowAmountRequested;

        _initialDeposit(_borrower, _collateralAmount, _transferFromSavingsAccount);

        poolConstants.borrower = _borrower;
        poolConstants.minborrowAmount = _minborrowAmount;
        poolConstants.loanStartTime = block.timestamp.add(_collectionPeriod);
        poolConstants.loanWithdrawalDeadline = block.timestamp.add(_collectionPeriod).add(
                _loanWithdrawalDuration
            );
        
        poolConstants.borrowRate = _borrowRate;
        poolConstants.noOfRepaymentIntervals = _noOfRepaymentIntervals;
        poolConstants.repaymentInterval = _repaymentInterval;
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
        _depositCollateral(msg.sender, _amount, _transferFromSavingsAccount);
    }

    function _initialDeposit(
        address _borrower,
        uint256 _amount,
        bool _transferFromSavingsAccount
    ) internal {
        uint256 price = IPriceOracle(IPoolFactory(PoolFactory).priceOracle()).getLatestPrice(poolConstants.borrowAsset, poolConstants.collateralAsset);
        require(_amount >= poolConstants.idealCollateralRatio.mul(poolConstants.borrowAmountRequested.mul(price)).div(1e16), "36"); 

        _depositCollateral(_borrower, _amount, _transferFromSavingsAccount);
    }

    function _depositCollateral(
        address _borrower,
        uint256 _amount,
        bool _transferFromSavingsAccount
    ) internal {
        uint256 _sharesReceived =
            _deposit(
                _transferFromSavingsAccount,
                true,
                poolConstants.collateralAsset,
                _amount,
                poolConstants.poolSavingsStrategy,
                _borrower,
                address(this)
            );

        poolVars.baseLiquidityShares = poolVars.baseLiquidityShares.add(
            _sharesReceived
        );
        emit CollateralAdded(_borrower, _amount, _sharesReceived);
    }

    function _deposit(
        bool _fromSavingsAccount,
        bool _toSavingsAccount,
        address _asset,
        uint256 _amount,
        address _poolSavingsStrategy,
        address _depositFrom,
        address _depositTo
    ) internal returns (uint256) {
        ISavingsAccount _savingsAccount =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        uint256 _sharesReceived;
        if (!_fromSavingsAccount) {
            _sharesReceived = _amount;
            if(_asset == address(0)) {
                uint256 _tokensSent = msg.value;
                require(
                    _tokensSent >= _amount,
                    "8"
                );
                if(_toSavingsAccount) {
                    _sharesReceived = _savingsAccount.depositTo{value: _amount}(
                        _amount,
                        _asset,
                        _poolSavingsStrategy,
                        _depositTo
                    );
                    
                }
                if(_tokensSent > _amount) {
                    msg.sender.transfer(_tokensSent.sub(_amount));
                }
            } else {
                IERC20(_asset).safeTransferFrom(
                    _depositFrom,
                    address(this),
                    _amount
                );
                if(_toSavingsAccount) {
                    IERC20(_asset).safeApprove(address(_savingsAccount), _amount);
                    _sharesReceived = _savingsAccount.depositTo(
                        _amount,
                        _asset,
                        _poolSavingsStrategy,
                        _depositTo
                    );
                }
            }
        } else {
            uint256 _liquidityshare =
                    IYield(_poolSavingsStrategy).getTokensForShares(_amount, _asset);
            if(_toSavingsAccount) {
                _sharesReceived = _savingsAccount.transferFrom(
                    _asset,
                    _depositFrom,
                    address(this),
                    _poolSavingsStrategy,
                    _liquidityshare
                );
            } else {
                _savingsAccount.withdrawFrom(
                    _depositFrom,
                    address(this),
                    _liquidityshare,
                    _asset,
                    _poolSavingsStrategy,
                    true
                );
            }
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
            _deposit(
                _transferFromSavingsAccount,
                true,
                poolConstants.collateralAsset,
                _amount,
                poolConstants.poolSavingsStrategy,
                msg.sender,
                address(this)
            );

        poolVars.extraLiquidityShares = poolVars.extraLiquidityShares.add(
            _sharesReceived
        );

        lenders[_lender].extraLiquidityShares = lenders[_lender]
            .extraLiquidityShares
            .add(_sharesReceived);

        if(getCurrentCollateralRatio(_lender) >= poolConstants.idealCollateralRatio) {
            delete lenders[_lender].marginCallEndTime;
        }

        emit MarginCallCollateralAdded(
            msg.sender,
            _lender,
            _amount,
            _sharesReceived
        );
    }

    function withdrawBorrowedAmount() external override OnlyBorrower(msg.sender) nonReentrant {
        LoanStatus _poolStatus = poolVars.loanStatus;
        require(
            _poolStatus == LoanStatus.COLLECTION &&
                poolConstants.loanStartTime < block.timestamp,
            "12"
        );

        uint256 _tokensLent = poolToken.totalSupply();

        if (
            _tokensLent < poolConstants.minborrowAmount
        ) {
            _cancelPool();
        }

        poolVars.loanStatus = LoanStatus.ACTIVE;
        
        uint256 _currentCollateralRatio = getCurrentCollateralRatio();
        IPoolFactory _poolFactory = IPoolFactory(PoolFactory);
        require(
            _currentCollateralRatio >
                poolConstants.idealCollateralRatio.sub(
                    _poolFactory.collateralVolatilityThreshold()
                ),
            "13"
        );
        uint256 _noOfRepaymentIntervals = poolConstants.noOfRepaymentIntervals;
        uint256 _repaymentInterval = poolConstants.repaymentInterval;
        IRepayment(_poolFactory.repaymentImpl()).initializeRepayment(_noOfRepaymentIntervals, _repaymentInterval, poolConstants.borrowRate, poolConstants.loanStartTime, poolConstants.borrowAsset);
        IExtension(_poolFactory.extension()).initializePoolExtension(_repaymentInterval);
        IERC20(poolConstants.borrowAsset).transfer(
            poolConstants.borrower,
            _tokensLent
        );

        delete poolConstants.loanWithdrawalDeadline;
        emit AmountBorrowed(_tokensLent);
    }


    function withdrawAllCollateral() internal {
        uint256 _collateralShares =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);

        uint256 _sharesReceived =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount())
                .transfer(
                poolConstants.collateralAsset,
                msg.sender,
                poolConstants.poolSavingsStrategy,
                _collateralShares
            );
        emit CollateralWithdrawn(msg.sender, _sharesReceived);
        delete poolVars.baseLiquidityShares;
        delete poolVars.extraLiquidityShares;
    }

    function lend(address _lender, uint256 _amountLent, bool _fromSavingsAccount) external payable nonReentrant {
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
        _deposit(
            _fromSavingsAccount,
            false,
            _borrowToken,
            _amount,
            address(0),
            msg.sender,
            address(this)
        );
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
        LoanStatus _poolStatus = poolVars.loanStatus;
        require(_poolStatus == LoanStatus.COLLECTION || _poolStatus == LoanStatus.CANCELLED, "20");
        _cancelPool();
    }

    function _cancelPool() internal {
        poolVars.loanStatus = LoanStatus.CANCELLED;
        IExtension(IPoolFactory(PoolFactory).extension()).closePoolExtension();
        withdrawAllCollateral();
        poolToken.pause();
        emit OpenBorrowPoolCancelled();
    }

    function terminateOpenBorrowPool() external onlyOwner {
        // TODO: Add delay before the transfer to admin can happen
        uint256 _collateralShares =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);
        ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount()).transfer(
            poolConstants.collateralAsset,
            IPoolFactory(PoolFactory).owner(),
            poolConstants.poolSavingsStrategy,
            _collateralShares
        );
        poolToken.pause();
        poolVars.loanStatus = LoanStatus.TERMINATED;
        IExtension(IPoolFactory(PoolFactory).extension()).closePoolExtension();
        emit OpenBorrowPoolTerminated();
    }

    function closeLoan() external payable OnlyBorrower(msg.sender) {
        require(
            poolVars.loanStatus == LoanStatus.ACTIVE,
            "22"
        );
        require(
            poolVars.nextDuePeriod == 0,
            "23"
        );
        uint256 _principleToPayback = poolToken.totalSupply();
        address _borrowAsset = poolConstants.borrowAsset;
        if(_borrowAsset == address(0)) {
            require(msg.value == _principleToPayback, "37");
        } else {
            IERC20(_borrowAsset).safeTransferFrom(msg.sender, address(this), _principleToPayback);
        }
        
        poolVars.loanStatus = LoanStatus.CLOSED;
        IExtension(IPoolFactory(PoolFactory).extension()).closePoolExtension();
        withdrawAllCollateral();
        poolToken.pause();
        emit OpenBorrowPoolClosed();
    }

    // Note - Only when closed, cancelled or terminated, lender can withdraw
    //burns all shares and returns total remaining repayments along with provided liquidity
    function withdrawLiquidity() external isLender(msg.sender) nonReentrant {
        LoanStatus _loanStatus = poolVars.loanStatus;

        if (
            _loanStatus == LoanStatus.COLLECTION && 
            poolConstants.loanStartTime < block.timestamp && 
            poolToken.totalSupply() < poolConstants.minborrowAmount
        ) {
            poolVars.loanStatus = LoanStatus.CANCELLED;
        }
        require(
            _loanStatus == LoanStatus.CLOSED ||
                _loanStatus == LoanStatus.CANCELLED ||
                _loanStatus == LoanStatus.DEFAULTED,
            "24"
        );

        //get total repayments collected as per loan status (for closed, it returns 0)
        // uint256 _due = calculateRepaymentWithdrawable(msg.sender);

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

        // _due = _balance.add(_due);

        // lenders[msg.sender].amountWithdrawn = lenders[msg.sender]
        //     .amountWithdrawn
        //     .add(_due);
        delete lenders[msg.sender].principalWithdrawn;

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
        emit LiquidityWithdrawn(_balance, msg.sender);
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
            poolConstants.idealCollateralRatio >
                getCurrentCollateralRatio(msg.sender).add(
                    IPoolFactory(PoolFactory).collateralVolatilityThreshold()
                ),
            "26"
        );

        lenders[msg.sender].marginCallEndTime = block.timestamp.add(
            IPoolFactory(PoolFactory).marginCallDuration()
        );

        emit MarginCalled(msg.sender);
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

    function interestTillNow(uint256 _balance)
        public
        view
        returns (uint256)
    {
        uint256 _totalSupply = poolToken.totalSupply();
        uint256 _interestPerPeriod =  interestPerPeriod(_balance);

        IPoolFactory _poolFactory = IPoolFactory(PoolFactory);

        (uint256 _repaymentPeriodCovered, uint256 _repaymentOverdue) = IRepayment(_poolFactory.repaymentImpl()).getInterestCalculationVars(address(this));

        uint256 _interestAccruedThisPeriod = ((block.timestamp).sub(_repaymentPeriodCovered)).mul(_interestPerPeriod);

        uint256 _totalInterest = (_interestAccruedThisPeriod.add(_repaymentOverdue)).mul(_balance).div(_totalSupply);
        return _totalInterest;
    }

    function calculateCollateralRatio(
        uint256 _balance,
        uint256 _liquidityShares
    ) public returns (uint256) {

        uint256 _interest = interestTillNow(_balance);

        address _collateralAsset = poolConstants.collateralAsset;

        uint256 _ratioOfPrices =IPriceOracle(IPoolFactory(PoolFactory).priceOracle()).getLatestPrice(_collateralAsset, poolConstants.borrowAsset);

        uint256 _currentCollateralTokens =IYield(poolConstants.poolSavingsStrategy).getTokensForShares(_liquidityShares,_collateralAsset);

        uint256 _ratio =(_currentCollateralTokens.mul(_ratioOfPrices).div(100000000)).div(_balance.add(_interest));

        return (_ratio);
    }

    function getCurrentCollateralRatio() public returns (uint256) {
        uint256 _liquidityShares =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);
        return (
            calculateCollateralRatio(
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
                _balanceOfLender,
                _liquidityShares
            )
        );
    }

    function liquidatePool(
        bool _fromSavingsAccount,
        bool _toSavingsAccount,
        bool _recieveLiquidityShare
    ) external payable nonReentrant {
        LoanStatus _currentPoolStatus;
        address _poolFactory = PoolFactory;
        if (poolVars.loanStatus != LoanStatus.DEFAULTED) {
            _currentPoolStatus = checkRepayment();
        }
        require(
            _currentPoolStatus == LoanStatus.DEFAULTED,
            "Pool::liquidatePool - No reason to liquidate the pool"
        );

        address _collateralAsset = poolConstants.collateralAsset;
        address _borrowAsset = poolConstants.borrowAsset;
        uint256 _collateralLiquidityShare =
            poolVars.baseLiquidityShares.add(poolVars.extraLiquidityShares);
        address _poolSavingsStrategy = poolConstants.poolSavingsStrategy;
        uint256 _collateralTokens =
                IYield(_poolSavingsStrategy).getTokensForShares(
                    _collateralLiquidityShare,
                    _collateralAsset
                );

        uint256 _poolBorrowTokens =
            correspondingBorrowTokens(_collateralTokens, _poolFactory);
        
        _deposit(
            _fromSavingsAccount,
            false,
            _borrowAsset,
            _poolBorrowTokens,
            address(0),
            msg.sender,
            address(this)
        );

        _withdraw(
            _toSavingsAccount,
            _recieveLiquidityShare,
            _collateralAsset,
            _poolSavingsStrategy,
            _collateralTokens,
            _collateralLiquidityShare
        );

        delete poolVars.extraLiquidityShares;
        delete poolVars.baseLiquidityShares;
        emit PoolLiquidated(msg.sender);
    }

    function _withdraw(
        bool _toSavingsAccount,
        bool _recieveLiquidityShare,
        address _asset,
        address _poolSavingsStrategy,
        uint256 _amountInTokens,
        uint256 _amountInShares
    ) internal returns(uint256 _amountReceived) {
        ISavingsAccount _savingsAccount =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        if (_toSavingsAccount) {
            _amountReceived = _savingsAccount.transfer(
                _asset,
                msg.sender,
                _poolSavingsStrategy,
                _amountInShares
            );
        } else {
            _amountReceived =
                _savingsAccount.withdraw(
                    payable(address(this)),
                    _amountInTokens,
                    _asset,
                    _poolSavingsStrategy,
                    _recieveLiquidityShare
                );
            if (_recieveLiquidityShare) {
                address _addressOfTheLiquidityToken =
                    IYield(_poolSavingsStrategy).liquidityToken(_asset);
                IERC20(_addressOfTheLiquidityToken).safeTransfer(
                    msg.sender,
                    _amountReceived
                );
            } else {
                if (_asset == address(0)) {
                    msg.sender.transfer(_amountReceived);
                } else {
                    IERC20(_asset).safeTransfer(
                        msg.sender,
                        _amountReceived
                    );
                }
            }
        }
    }

    function liquidateLender(
        address _lender,
        bool _fromSavingsAccount,
        bool _toSavingsAccount,
        bool _recieveLiquidityShare
    ) public payable nonReentrant {
        //avoid stack too deep
        address _poolFactory = PoolFactory;
        {
            require(
                (poolVars.loanStatus == LoanStatus.ACTIVE) &&
                    (block.timestamp > poolConstants.loanWithdrawalDeadline),
                "27"
            );
            uint256 _marginCallEndTime = lenders[_lender].marginCallEndTime;
            require(_marginCallEndTime != 0, "No margin call has been called.");
            require(
                _marginCallEndTime < block.timestamp,
                "28"
            );

            require(
                poolConstants.idealCollateralRatio.sub(
                    IPoolFactory(_poolFactory).collateralVolatilityThreshold()
                ) > getCurrentCollateralRatio(_lender),
                "29"
            );
            require(
                poolToken.balanceOf(_lender) != 0,
                "30"
            );
        }

        address _collateralAsset = poolConstants.collateralAsset;
        address _poolSavingsStrategy = poolConstants.poolSavingsStrategy;
        uint256 _lenderBalance = poolToken.balanceOf(_lender);
        uint256 _lenderCollateralLPShare;
        {
            uint256 _poolBaseLPShares = poolVars.baseLiquidityShares;
            uint256 _lenderBaseLPShares = (_poolBaseLPShares.mul(_lenderBalance)).div(poolToken.totalSupply());
            uint256 _lenderExtraLPShares = lenders[_lender].extraLiquidityShares;
            poolVars.baseLiquidityShares = _poolBaseLPShares.sub(_lenderBaseLPShares);
            poolVars.extraLiquidityShares = poolVars.extraLiquidityShares.sub(_lenderExtraLPShares);

            _lenderCollateralLPShare = _lenderBaseLPShares.add(_lenderExtraLPShares);
        }
        
        uint256 _lenderCollateralShare =
            IYield(_poolSavingsStrategy).getTokensForShares(
                _lenderCollateralLPShare,
                _collateralAsset
            );
        {
            uint256 _lenderLiquidationTokens =
                correspondingBorrowTokens(_lenderCollateralShare, _poolFactory);
            
            address _borrowAsset = poolConstants.borrowAsset;
            uint256 _sharesReceived = _deposit(
                _fromSavingsAccount,
                false,
                _borrowAsset,
                _lenderLiquidationTokens,
                _poolSavingsStrategy,
                msg.sender,
                address(this)
            );
            _withdrawRepayment(_lender, true);
            ISavingsAccount(IPoolFactory(_poolFactory).savingsAccount()).transfer(
                _borrowAsset,
                _lender,
                _poolSavingsStrategy,
                _sharesReceived
            );
        }

        uint256 _amountReceived = _withdraw(
            _toSavingsAccount,
            _recieveLiquidityShare,
            _collateralAsset,
            _poolSavingsStrategy,
            _lenderCollateralShare,
            _lenderCollateralLPShare
        );
        poolToken.burn(_lender, _lenderBalance);
        delete lenders[_lender];
        emit LenderLiquidated(msg.sender, _lender, _amountReceived);
    }


    function correspondingBorrowTokens(uint256 _collateralTokens, address _poolFactory)
        public
        view
        returns (uint256)
    {
        IPoolFactory _PoolFactory = IPoolFactory(_poolFactory);
        return
            (
                _collateralTokens
                    .mul(
                    IPriceOracle(_PoolFactory.priceOracle()).getLatestPrice(
                        poolConstants.collateralAsset,
                        poolConstants.borrowAsset
                    )
                )
                    .div(10**8)
            )
                .mul(
                uint256(10**8).sub(_PoolFactory.liquidatorRewardFraction())
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
                .sub(lenders[_lender].interestWithdrawn);

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
        address _poolSavingsStrategy = address(0); //add defaultStrategy

        _withdraw(
            _withdrawToSavingsAccount,
            false,
            poolConstants.borrowAsset,
            _poolSavingsStrategy,
            _amountToWithdraw,
            0
        );
        lenders[_lender].interestWithdrawn = lenders[_lender]
            .interestWithdrawn
            .add(_amountToWithdraw);
    }

    function getNextDuePeriod() external view override returns(uint256) {
        return poolVars.nextDuePeriod;
    }

    function getMarginCallEndTime(address _lender) external view override returns(uint256) {
        return lenders[_lender].marginCallEndTime;
    }

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
}
