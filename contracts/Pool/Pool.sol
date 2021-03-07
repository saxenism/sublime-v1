// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "../interfaces/IPoolFactory.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IYield.sol";
import "../interfaces/IRepayment.sol";
import "../interfaces/ISavingsAccount.sol";
import "../interfaces/IPool.sol";

// TODO: set modifiers to disallow any transfers directly
contract Pool is ERC20PresetMinterPauserUpgradeable,IPool {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    enum LoanStatus {
        COLLECTION, //denotes collection period
        ACTIVE,
        CLOSED,
        CANCELLED,
        DEFAULTED,
        TERMINATED
    }

    address public Repayment;
    // address public PriceOracle;
    address public PoolFactory;

    struct LendingDetails {
        uint256 amountWithdrawn;
        // bool lastVoteValue; // last vote value is not neccesary as in once cycle user can vote only once
        uint256 lastVoteTime;
        uint256 marginCallEndTime;
        uint256 extraLiquidityShares;
        bool canBurn;
    }

    address public borrower;
    uint256 public borrowAmountRequested;
    uint256 public minborrowAmountFraction; // min fraction for the loan to continue
    uint256 public loanStartTime;
    uint256 public matchCollateralRatioEndTime;
    address public borrowAsset;
    uint256 public collateralRatio;
    uint256 public borrowRate;
    uint256 public noOfRepaymentIntervals;
    uint256 public repaymentInterval;
    address public collateralAsset;
    
    uint256 public liquidatorRewardFraction;
    uint256 periodWhenExtensionIsRequested;
    uint256 public baseLiquidityShares;
    uint256 public extraLiquidityShares;
    uint256 public liquiditySharesTokenAddress;
    LoanStatus public loanStatus;
    uint256 public totalExtensionSupport; // sum of weighted votes for extension
    address public investedTo;  // invest contract
    mapping(address => LendingDetails) public lenders;
    uint256 public extensionVoteEndTime;
    uint256 public noOfGracePeriodsTaken;
    uint256 public nextDuePeriod;
    uint256 public gracePeriodPenaltyFraction;
    event OpenBorrowPoolCreated(address poolCreator);
    event OpenBorrowPoolCancelled();
    event OpenBorrowPoolTerminated();
    event OpenBorrowPoolClosed();
    event OpenBorrowPoolDefaulted();
    event CollateralAdded(address borrower,uint256 amount,uint256 sharesReceived);
    event MarginCallCollateralAdded(address borrower,address lender,uint256 amount,uint256 sharesReceived);
    event CollateralWithdrawn(address user, uint256 amount);
    event liquiditySupplied(
        uint256 amountSupplied,
        address lenderAddress
    );
    event AmountBorrowed(address borrower, uint256 amount);
    event liquiditywithdrawn(
        uint256 amount,
        address lenderAddress
    );
    event CollateralCalled(address lenderAddress);
    event lenderVoted(address Lender);
    event LoanDefaulted();
    event lenderLiquidated(address liquidator, address lender,uint256 _tokenReceived);
    event PoolLiquidated(address liquidator);

    modifier OnlyBorrower {
        require(msg.sender == borrower, "Pool::OnlyBorrower - Only borrower can invoke");
        _;
    }

    modifier isLender(address _lender) {
        require(balanceOf(_lender) != 0, "Pool::isLender - Lender doesn't have any lTokens for the pool");
        _;
    }

    modifier onlyOwner {
        require(msg.sender == IPoolFactory(PoolFactory).owner(), "Pool::onlyOwner - Only owner can invoke");
        _;
    }

    modifier isPoolActive {
        require(loanStatus == LoanStatus.ACTIVE, "Pool::isPoolActive - Pool is  not active");
        _;
    }

    // TODO - decrease the number of arguments - stack too deep
    function initialize(
        uint256 _borrowAmountRequested,
        uint256 _minborrowAmountFraction, // represented as %
        address _borrower,
        address _borrowAsset,
        address _collateralAsset,
        uint256 _collateralRatio,
        uint256 _borrowRate,
        uint256 _repaymentInterval,
        uint256 _noOfRepaymentIntervals,
        address _investedTo,
        uint256 _collateralAmount,
        bool _transferFromSavingsAccount,
        uint256 _gracePeriodPenaltyFraction
    ) external initializer {
        super.initialize("Open Pool Tokens", "OPT");
        initializePoolParams(
            _borrowAmountRequested,
            _minborrowAmountFraction, // represented as %
            _borrower,
            _borrowAsset,
            _collateralAsset,
            _collateralRatio,
            _borrowRate,
            _repaymentInterval,
            _noOfRepaymentIntervals,
            _investedTo,
            _gracePeriodPenaltyFraction
        );
        PoolFactory = msg.sender;

        depositCollateral(_collateralAmount, _transferFromSavingsAccount);
        uint256 collectionPeriod = IPoolFactory(msg.sender).collectionPeriod();
        loanStartTime = block.timestamp.add(collectionPeriod);
        matchCollateralRatioEndTime = block.timestamp.add(collectionPeriod).add(IPoolFactory(msg.sender).matchCollateralRatioInterval());

        emit OpenBorrowPoolCreated(msg.sender);
    }

    function initializePoolParams(
        uint256 _borrowAmountRequested,
        uint256 _minborrowAmountFraction, // represented as %
        address _borrower,
        address _borrowAsset,
        address _collateralAsset,
        uint256 _collateralRatio,
        uint256 _borrowRate,
        uint256 _repaymentInterval,
        uint256 _noOfRepaymentIntervals,
        address _investedTo,
        uint256 _gracePeriodPenaltyFraction
    ) internal {
        borrowAmountRequested = _borrowAmountRequested;
        minborrowAmountFraction = _minborrowAmountFraction;
        borrower = _borrower;
        borrowAsset = _borrowAsset;
        collateralAsset = _collateralAsset;
        collateralRatio = _collateralRatio;
        borrowRate =  _borrowRate;
        repaymentInterval = _repaymentInterval;
        noOfRepaymentIntervals = _noOfRepaymentIntervals;
        investedTo = _investedTo;
        gracePeriodPenaltyFraction = _gracePeriodPenaltyFraction;
    }

    // Deposit collateral
    function depositCollateral(uint256 _amount,bool _transferFromSavingsAccount) public payable override {

        require(_amount != 0, "Pool::deposit - collateral amount");
        uint256 _sharesReceived;
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        address _collateralAsset = collateralAsset;
        address _investedTo = investedTo;

        if(!_transferFromSavingsAccount){
            if(_collateralAsset == address(0)) {
                require(msg.value == _amount, "Pool::deposit - value to transfer doesn't match argument");
                _sharesReceived = _savingAccount.deposit{value:msg.value}(_amount,_collateralAsset,_investedTo, address(this));
            }
            else{
                _sharesReceived = _savingAccount.deposit(_amount,_collateralAsset,_investedTo, address(this));
            }
        }
        else{
            uint256 _liquidityshare = IYield(_investedTo).getTokensForShares(_amount, _collateralAsset);
            _sharesReceived = _savingAccount.transferFrom(msg.sender, address(this), _liquidityshare, _collateralAsset,_investedTo);
        }
        baseLiquidityShares = baseLiquidityShares.add(_sharesReceived);
        emit CollateralAdded(msg.sender,_amount,_sharesReceived);
    } 



    function addCollateralInMarginCall(address _lender,  uint256 _amount,bool _transferFromSavingsAccount) external payable override
    {
        require(loanStatus == LoanStatus.ACTIVE, "Pool::addCollateralMarginCall - Loan needs to be in Active stage to deposit"); 
        require(lenders[_lender].marginCallEndTime >= block.timestamp, "Pool::addCollateralMarginCall - Can't Add after time is completed");
        require(_amount !=0, "Pool::addCollateralMarginCall - collateral amount");

        uint256 _sharesReceived;
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        address _collateralAsset = collateralAsset;
        address _investedTo = investedTo;
        

        if(!_transferFromSavingsAccount){
            if(_collateralAsset == address(0)) {
                require(msg.value == _amount, "Pool::addCollateralMarginCall - value to transfer doesn't match argument");
                _sharesReceived = _savingAccount.deposit{value:msg.value}(_amount,_collateralAsset,_investedTo, address(this));
            }
            else{
                _sharesReceived = _savingAccount.deposit(_amount,_collateralAsset,_investedTo, address(this));
            }
        }
        else{
            uint256 _liquidityshare = IYield(_investedTo).getTokensForShares(_amount, _collateralAsset);
            _sharesReceived = _savingAccount.transferFrom(msg.sender, address(this), _liquidityshare, _collateralAsset,_investedTo);
        }

        extraLiquidityShares = extraLiquidityShares.add(_sharesReceived);
        lenders[_lender].extraLiquidityShares = lenders[_lender].extraLiquidityShares.add(_sharesReceived);
        emit MarginCallCollateralAdded(msg.sender,_lender,_amount,_sharesReceived);
    }	    
    

    function withdrawBorrowedAmount()
        external
        OnlyBorrower override
    {
        LoanStatus _poolStatus = loanStatus;
        if(_poolStatus == LoanStatus.COLLECTION && loanStartTime < block.timestamp) {
            if(totalSupply() < borrowAmountRequested.mul(minborrowAmountFraction).div(100)) {
                loanStatus = LoanStatus.CANCELLED;
                return;
            }
            loanStatus = LoanStatus.ACTIVE;
        }
        require(
            (loanStatus == LoanStatus.ACTIVE) && (matchCollateralRatioEndTime!=0),
            "Pool::withdrawBorrowedAmount - Loan is not in ACTIVE state"
        );
        uint256 _currentCollateralRatio = getCurrentCollateralRatio();
        require(_currentCollateralRatio > collateralRatio.sub(IPoolFactory(PoolFactory).collateralVolatilityThreshold()), "Pool::withdrawBorrowedAmount - The current collateral amount does not permit the loan.");

        uint256 _tokensLent = totalSupply();
        IERC20(borrowAsset).transfer(borrower, _tokensLent);
        
        delete matchCollateralRatioEndTime;
        emit AmountBorrowed(
            msg.sender,
            _tokensLent
        );   
    }


    function repayAmount(uint256 amount)
        external
        OnlyBorrower
        isPoolActive
    {
        
    }

    function withdrawAllCollateral()
        external
        OnlyBorrower
    {
        LoanStatus _status = loanStatus;
        require(
            _status == LoanStatus.CLOSED || _status == LoanStatus.CANCELLED,
            "Pool::withdrawAllCollateral: Loan is not CLOSED or CANCELLED"
        );

        uint256 _collateralShares = baseLiquidityShares.add(extraLiquidityShares);
        uint256 _sharesReceived = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount()).transfer(msg.sender,_collateralShares,collateralAsset,investedTo);
        emit CollateralWithdrawn(msg.sender, _sharesReceived);
        delete baseLiquidityShares;
        delete extraLiquidityShares;
    }


    function lend(address _lender, uint256 _amountLent) external payable{
        require(loanStatus == LoanStatus.COLLECTION, "Pool::lend - The pool should be in Collection Period.");

        uint256 _amount = _amountLent;
        uint256 _borrowAmountNeeded = borrowAmountRequested;
        if(_amountLent.add(totalSupply()) > _borrowAmountNeeded) {
            _amount = _borrowAmountNeeded.sub(totalSupply());
        }

        address _borrowToken = borrowAsset;
        if(_borrowToken == address(0)) {
            require(_amountLent == msg.value, "Pool::lend - Ether value is not same as parameter passed");
            if(_amount != _amountLent) {
                msg.sender.send(_amountLent.sub(_amount));
            }
        } else {
            IERC20(_borrowToken).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }
        mint(_lender, _amount);
        emit liquiditySupplied(_amount, _lender);
    }

    function _beforeTransfer(address _user) internal {
        
    }

    function transfer(address _recipient, uint256 _amount) public override returns(bool) {
        
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public virtual override returns (bool) {
        
    }


    function cancelOpenBorrowPool()
        external
        OnlyBorrower
    {   
        LoanStatus _poolStatus = loanStatus;
        require(
            _poolStatus == LoanStatus.COLLECTION || (_poolStatus == LoanStatus.ACTIVE && block.timestamp<matchCollateralRatioEndTime), "Pool::cancelOpenBorrowPool - The pool cannot be cancelled when the status is active."
        );
        require(matchCollateralRatioEndTime == 0, "Pool::cancelOpenBorrowPool - The borrowedAmount has already been withdrawn.");
        loanStatus = LoanStatus.CANCELLED;
        _pause(); 
        emit OpenBorrowPoolCancelled();
    }

    function terminateOpenBorrowPool()
        external
        onlyOwner
    {
        LoanStatus _poolStatus = loanStatus;
        require(
            _poolStatus == LoanStatus.ACTIVE || _poolStatus == LoanStatus.COLLECTION,
            "Pool::terminateOpenBorrowPool - The pool can only be terminated if it is Active or Collection Period."
        );
        if (matchCollateralRatioEndTime == 0){
            emit LoanDefaulted();
        }
        else{
            uint256 _collateralShares = baseLiquidityShares.add(extraLiquidityShares);
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount()).transfer(IPoolFactory(PoolFactory).owner(), _collateralShares, collateralAsset, investedTo);
        }
        _pause();
        loanStatus = LoanStatus.TERMINATED; 
        emit OpenBorrowPoolTerminated();
    }

    function closeLoan()
        external   
        OnlyBorrower
    {
        require(
            loanStatus == LoanStatus.ACTIVE,
            "Pool::closeLoan - The pool can only be closed if the loan is Active."
        );
        uint256 _totalAsset;
        if (borrowAsset != address(0)) {
            _totalAsset = IERC20(borrowAsset).balanceOf(address(this));
        } else {
            _totalAsset = address(this).balance;
        }
        // assuming that the principle is transferred to the pool.
        require(nextDuePeriod==0 && _totalAsset>totalSupply(), "Pool::closeLoan - The loan has not been fully repayed.");
        loanStatus = LoanStatus.CLOSED;
        _pause();
        emit OpenBorrowPoolClosed();
    }

    function calculateLendingRate(uint256 s) public pure returns (uint256) {
        
    }

    // Note - Only when cancelled or terminated, lender can withdraw
    function withdrawLiquidity(address lenderAddress)
        external
    {
    }


    function resultOfVoting() external {
        
    }

    function requestExtension() external OnlyBorrower isPoolActive
    {
        
    }


    function voteOnExtension() external isPoolActive 
    {
        
    }

    function requestCollateralCall()
        public
    {
        
    }

    

    function transferRepayImpl(address repayment) external onlyOwner {
        
    }

    // function transferLenderImpl(address lenderImpl) external onlyOwner {
    //     require(lenderImpl != address(0), "Borrower: Lender address");
    //     _lender = lenderImpl;
    // }

    // event PoolLiquidated(bytes32 poolHash, address liquidator, uint256 amount);
    //todo: add more details here
    event Liquidated(address liquidator, address lender);

    function amountPerPeriod() public view returns(uint256){
        
    }

    function interestTillNow(uint256 _balance, uint256 _interestPerPeriod) public view returns(uint256){
        uint256 _repaymentLength = repaymentInterval;
        uint256 _loanStartedAt = loanStartTime;
        uint256 _totalSupply = totalSupply();
        (uint256 _interest, uint256 _gracePeriodsTaken) =
            (
                IRepayment(Repayment).calculateRepayAmount(
                    _totalSupply,
                    _repaymentLength,
                    borrowRate,
                    _loanStartedAt,
                    nextDuePeriod,
                    periodWhenExtensionIsRequested
                )
            );
        uint256 _extraInterest =
            interestPerSecond(_balance).mul(
                ((calculateCurrentPeriod().add(1)).mul(_repaymentLength))
                    .add(_loanStartedAt)
                    .sub(block.timestamp)
            );
        _interest = _interest.sub(
            gracePeriodPenaltyFraction.mul(_interestPerPeriod).div(100).mul(
                _gracePeriodsTaken
            )
        );
        if (_interest < _extraInterest) {
            _interest = 0;
        } else {
            _interest = _interest.sub(_extraInterest);
        }
    }

    function calculateCollateralRatio(uint256 _interestPerPeriod, uint256 _balance, uint256 _liquidityShares) public returns(uint256){
        uint256 _interest = interestTillNow(_balance, _interestPerPeriod);
        address _collateralAsset = collateralAsset;
        uint256 _ratioOfPrices =
            IPriceOracle(IPoolFactory(PoolFactory).priceOracle())
                .getLatestPrice(_collateralAsset, borrowAsset);
        uint256 _currentCollateralTokens =
            IYield(investedTo).getTokensForShares(
                _liquidityShares,
                _collateralAsset
            );
        uint256 _ratio = (_currentCollateralTokens.mul(_ratioOfPrices).div(100000000)).div(
            _balance.add(_interest)
        );
        return(_ratio);
    }

    function getCurrentCollateralRatio() public returns (uint256) {
        uint256 _liquidityShares = baseLiquidityShares.add(extraLiquidityShares);
        return(calculateCollateralRatio(amountPerPeriod(), totalSupply(), _liquidityShares));
    }

    function getCurrentCollateralRatio(address _lender)
        public
        returns (uint256 _ratio)
    {
        uint256 _balanceOfLender = balanceOf(_lender);
        uint256 _liquidityShares = (baseLiquidityShares.mul(_balanceOfLender).div(totalSupply()))
                    .add(lenders[_lender].extraLiquidityShares); 
        return(calculateCollateralRatio(interestPerPeriod(balanceOf(_lender)), _balanceOfLender, _liquidityShares));
    }
   
    function liquidateLender(address lender,bool _transferToSavingsAccount,bool _recieveLiquidityShare)
        public payable
    {
        require(
            (loanStatus == LoanStatus.ACTIVE) && (block.timestamp > matchCollateralRatioEndTime),
            "Pool::liquidateLender - Borrower Extra time to match collateral is running"
        );
        uint256 _marginCallEndTime = lenders[lender].marginCallEndTime;
        require(_marginCallEndTime!=0, "No margin call has been called.");
        require(
            _marginCallEndTime <
                block.timestamp,
            "Pool::liquidateLender - period for depositing extra collateral not ended"
        );
        require(
            collateralRatio.sub(IPoolFactory(PoolFactory).collateralVolatilityThreshold()) >
                getCurrentCollateralRatio(lender),
            "Pool::liquidateLender - collateral ratio has not reached threshold yet"
        );
        require(balanceOf(lender)!=0, "The user has already transferred all this tokens.");
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
     
        address _collateralAsset = collateralAsset;
        address _investedTo = investedTo;
        uint256 _collateralLiquidityShare = ((baseLiquidityShares.mul(balanceOf(lender))).div(totalSupply())).add(lenders[lender].extraLiquidityShares);
        uint256 _collateralTokens = IYield(_investedTo).getTokensForShares(_collateralLiquidityShare, _collateralAsset);
        
        uint256 _correspondingBorrowTokens=
            correspondingBorrowTokens(_collateralLiquidityShare);
        address _borrowAsset = borrowAsset;
        if (_borrowAsset == address(0)){
            if(msg.value<_correspondingBorrowTokens){
                revert("Pool::liquidateLender - Not enough tokens");
            }
        }
        else{
            IERC20(_borrowAsset).transferFrom(
                msg.sender,
                address(this),
                _correspondingBorrowTokens
            );
        }
        _withdrawRepayment(lender);
        uint256 _amountReceived;
        if(_transferToSavingsAccount){
            _amountReceived = _savingAccount.transfer(msg.sender, _collateralLiquidityShare, _collateralAsset, investedTo);
        }
        else{
            _amountReceived = _savingAccount.withdraw(_collateralTokens, _collateralAsset, _investedTo, _recieveLiquidityShare);
            if(_recieveLiquidityShare){
                address _liquidityShareAddress = IYield(_investedTo).liquidityToken(_collateralAsset);
                IERC20(_liquidityShareAddress).transfer(msg.sender, _amountReceived);
            }
            else{
                if(_collateralAsset == address(0)){
                    msg.sender.send(_amountReceived);
                }
                else{
                    IERC20(_collateralAsset).transfer(msg.sender, _amountReceived);
                }
            }
        }
        uint256 _sharesReceived;
        if(_borrowAsset == address(0)) {
            _sharesReceived = _savingAccount.deposit{value:msg.value}(_correspondingBorrowTokens, _borrowAsset, _investedTo, address(this));
        }
        else{
            _sharesReceived = _savingAccount.deposit(_correspondingBorrowTokens, _borrowAsset, _investedTo, address(this));
        }
        _savingAccount.transfer(lender, _sharesReceived, _borrowAsset, investedTo);
        burnFrom(lender,balanceOf(lender));
        delete lenders[lender];
        emit lenderLiquidated(msg.sender, lender, _amountReceived);
    }

    function correspondingBorrowTokens(uint256 _liquidityShares) public returns(uint256){
        uint256 _collateralTokens = IYield(investedTo).getTokensForShares(_liquidityShares, collateralAsset);
        uint256 _correspondingBorrowTokens = 
            (_collateralTokens.mul(IPriceOracle(IPoolFactory(PoolFactory).priceOracle()).getLatestPrice(
                borrowAsset,
                collateralAsset
            )).div(10**8)).mul(uint256(10**8).sub(liquidatorRewardFraction)).div(10**8);
    }

    function checkRepayment() public {
        _isRepaymentDone();
    }

    function _isRepaymentDone() internal returns(LoanStatus){
        // TODO

        return loanStatus;
    }


    function liquidatePool(bool _transferToSavingsAccount, bool _recieveLiquidityShare) external payable {
        LoanStatus _poolStatus = loanStatus;
        require(
            _poolStatus == LoanStatus.DEFAULTED,
            "Pool::liquidatePool - Borrower Extra time to match collateral is running"
        );
        LoanStatus _currentPoolStatus;
        if(_poolStatus!=LoanStatus.DEFAULTED){
            _currentPoolStatus = _isRepaymentDone();
        }
        require(_currentPoolStatus==LoanStatus.DEFAULTED, "Pool::liquidatePool - No reason to liquidate the pool");
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
     
        address _collateralAsset = collateralAsset;
        address _borrowAsset = borrowAsset;
        uint256 _collateralLiquidityShare = baseLiquidityShares.add(extraLiquidityShares);  
        uint256 _correspondingBorrowTokens = correspondingBorrowTokens(_collateralLiquidityShare);

        if (_borrowAsset == address(0)){
            if(msg.value<_correspondingBorrowTokens){
                revert("Pool::liquidatePool - Not enough tokens");
            }
        }
        else{
            IERC20(_borrowAsset).transferFrom(
                msg.sender,
                address(this),
                _correspondingBorrowTokens
            );
        }
        address _investedTo = investedTo;
        if(_transferToSavingsAccount){
            uint256 _sharesReceived = _savingAccount.transfer(msg.sender, _collateralLiquidityShare, _collateralAsset, _investedTo);
        }
        else{
            uint256 _collateralTokens = IYield(_investedTo).getTokensForShares(_collateralLiquidityShare, _collateralAsset);
            uint256 _amountReceived = _savingAccount.withdraw(_collateralTokens, _collateralAsset, _investedTo, _recieveLiquidityShare);
            if(_recieveLiquidityShare){
                address _addressOfTheLiquidityToken = IYield(_investedTo).liquidityToken(_collateralAsset);
                IERC20(_addressOfTheLiquidityToken).transfer(msg.sender, _amountReceived);
            }
            else{
                if(_collateralAsset == address(0)){
                    msg.sender.send(_amountReceived);
                }
                else{
                    IERC20(_collateralAsset).transfer(msg.sender, _amountReceived);
                }
            }
        }
        emit PoolLiquidated(msg.sender);
    }

    function interestPerSecond(uint256 _principle)
        public
        view
        returns (uint256)
    {
        uint256 _interest = ((_principle).mul(borrowRate)).div(365 days);
        return _interest;
    }
    
    function interestPerPeriod(uint256 _balance)
        public
        view
        returns (uint256)
    {
        return (interestPerSecond(_balance).mul(repaymentInterval));
    }

    function calculateCurrentPeriod() public view returns (uint256) {
        uint256 _currentPeriod =
            (block.timestamp.sub(loanStartTime, "Pool:: calculateCurrentPeriod - The loan has not started.")).div(repaymentInterval);
        return _currentPeriod;
    }
    
    // Withdraw Repayment, Also all the extra state variables are added here only for the review
    
    function withdrawRepayment() external payable {
        
    }

    function transferTokensRepayments(uint256 amount, address from, address to) internal{
        
    }

    function calculatewithdrawRepayment(address lender) public view returns(uint256)
    {
        
    }


    function _withdrawRepayment(address lender) internal {

        

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