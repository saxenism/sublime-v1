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
    uint256 PeriodWhenExtensionIsRequested;
    uint256 public baseLiquidityShares;
    uint256 public extraLiquidityShares;
    uint256 public liquiditySharesTokenAddress;
    LoanStatus public loanStatus;
    uint256 public totalExtensionSupport; // sum of weighted votes for extension
    address public investedTo;  // invest contract
    mapping(address => LendingDetails) public lenders;
    uint256 public extensionVoteEndTime;
    uint256 public noOfGracePeriodsTaken;
    uint256 nextDuePeriod;

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
        uint256 _collatoralAmount
    ) external initializer {
        
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
        uint256 _collatoralAmount
    ) internal {
        
    }

    function setGlobalParams(address _poolFactory) internal {
        
    }

    // Deposit collateral
    function deposit(uint256 _amount,bool _isDirect) external payable override {

        require(_amount != 0, "Pool::deposit - collateral amount");
        uint256 _sharesReceived;
        ISavingAccount _savingAccount = ISavingAccount(IPoolFactory(PoolFactory).SavingAccount());
        address _collateralAsset = collateralAsset;
        address _investedTo = investedTo;
        uint256 _liquidityshare = IYield(_investedTo).getTokensForShares(_amount, _collateralAsset);

        if(_isDirect){
            if(_collateralAsset == address(0)) {
                require(msg.value == _amount, "Pool::deposit - value to transfer doesn't match argument");
                _sharesReceived = _savingAccount.deposit{value:msg.value}(_amount,_collateralAsset,_investedTo, address(this));
            }
            else{
                _sharesReceived = _savingAccount.deposit(_amount,_collateralAsset,_investedTo, address(this));
            }
        }
        else{
            _sharesReceived = _savingAccount.transferFrom(msg.sender, address(this), _liquidityshare, _collateralAsset,_investedTo);
        }
        baseLiquidityShares = baseLiquidityShares.add(_sharesReceived);
        emit CollateralAdded(msg.sender,_amount,_sharesReceived);
    } 



    function addCollateralInMarginCall(address _lender,  uint256 _amount,bool _isDirect) external payable override
    {
        require(loanStatus == LoanStatus.ACTIVE, "Pool::addCollateralMarginCall - Loan needs to be in Active stage to deposit"); 
        require(lenders[_lender].marginCallEndTime >= block.timestamp, "Pool::addCollateralMarginCall - Can't Add after time is completed");
        require(_amount !=0, "Pool::addCollateralMarginCall - collateral amount");

        uint256 _sharesReceived;
        ISavingAccount _savingAccount = ISavingAccount(IPoolFactory(PoolFactory).SavingAccount());
        address _collateralAsset = collateralAsset;
        address _investedTo = investedTo;
        uint256 _liquidityshare = IYield(_investedTo).getTokensForShares(_amount, _collateralAsset);

        if(_isDirect){
            if(_collateralAsset == address(0)) {
                require(msg.value == _amount, "Pool::addCollateralMarginCall - value to transfer doesn't match argument");
                _sharesReceived = _savingAccount.deposit{value:msg.value}(_amount,_collateralAsset,_investedTo, address(this));
            }
            else{
                _sharesReceived = _savingAccount.deposit(_amount,_collateralAsset,_investedTo, address(this));
            }
        }
        else{
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
        if(loanStatus == LoanStatus.COLLECTION && loanStartTime < block.timestamp) {
            if(totalSupply() < borrowAmountRequested.mul(minborrowAmountFraction).div(100)) {
                loanStatus = LoanStatus.CANCELLED;
                return;
            }
            loanStatus = LoanStatus.ACTIVE;
        }
        require(
            loanStatus == LoanStatus.ACTIVE,
            "Borrower: Loan is not in ACTIVE state"
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
        uint256 _sharesReceived = ISavingAccount(IPoolFactory(PoolFactory).SavingAccount()).transfer(msg.sender,_collateralShares,collateralAsset,investedTo);
        emit CollateralWithdrawn(msg.sender, _sharesReceived);
        delete baseLiquidityShares;
        delete extraLiquidityShares;
    }


    function lend(address _lender, uint256 _amountLent) external {
        
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
        
    }


    
    function terminateOpenBorrowPool()
        external
        onlyOwner
    {
        
    }

    // TODO: repay function will invoke this fn
    function closeLoan()
        internal
        // onlyOwner // TODO: to be updated  --fixed
    {
        
    }

    // TODO: When repay is missed (interest/principle) call this
    function defaultLoan()
        internal
        // onlyOwner // TODO: to be updated
    {
        
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

    // TODO
    function getCurrentCollateralRatio()
        public
        returns (uint256 ratio)
    {
        
    }

    // TODO
    function getCurrentCollateralRatio(address _lender)
        public
        returns (uint256 ratio) {

    }
   
    function liquidateLender(address lender,bool _transferToSavingsAccount,bool _recieveLiquidityShare)
        public payable
    {

        require(
            block.timestamp > matchCollateralRatioEndTime,
            "Pool::liquidateLender - Borrower Extra time to match collateral is running"
        );
        require(
            lenders[lender].marginCallEndTime <
                block.timestamp,
            "Pool::liquidateLender - period for depositing extra collateral not ended"
        );
        require(
            collateralRatio.sub(IPoolFactory(PoolFactory).collateralVolatilityThreshold()) >
                getCurrentCollateralRatio(lender),
            "Pool::liquidateLender - collateral ratio has not reached threshold yet"
        );

        ISavingAccount _savingAccount = ISavingAccount(IPoolFactory(PoolFactory).SavingAccount());
     
        uint256 _collateralShareOfLender;
        uint256 _amountToBeRepaid;
        address _collateralAsset = collateralAsset;
        address _investedTo = investedTo;
        uint256 _collateralLiquidityShare = ((baseLiquidityShares.mul(balanceOf(lender))).div(totalSupply())).add(lenders[lender].extraLiquidityShares);
        uint256 _collateralTokens = IYield(_investedTo).getTokensForShares(_collateralLiquidityShare, _collateralAsset);
        
        uint256 _correspondingBorrowTokens=
            correspondingBorrowTokens(_collateralLiquidityShare);


        address _liquidityShareAddress = IYield(_investedTo).liquidityToken(_collateralAsset);
 
        if (borrowAsset == address(0)){
            if(msg.value<_correspondingBorrowTokens){
                revert("Pool::liquidatePool - Not enough tokens");
            }
        }
        else{
            IERC20(borrowAsset).transferFrom(
                msg.sender,
                address(this),
                _correspondingBorrowTokens
            );
        }
    

        if(_transferToSavingsAccount == true){
            uint256 _sharesReceived = _savingAccount.transfer(msg.sender,_collateralLiquidityShare,_collateralAsset,investedTo);
            emit lenderLiquidated(msg.sender, lender,_sharesReceived);
        }
        else{

            if(_recieveLiquidityShare == true){
                uint256 _liquidityShareReceived = _savingAccount.withdraw(_collateralTokens,_collateralAsset,_investedTo,true);
                IERC20(_liquidityShareAddress).transfer(msg.sender, _liquidityShareReceived);
                emit lenderLiquidated(msg.sender, lender,_liquidityShareReceived);
            }
            else{
                uint256 _tokenReceived = _savingAccount.withdraw(_collateralTokens,_collateralAsset,_investedTo,false);
                if(_collateralAsset == address(0)){
                    msg.sender.send(_tokenReceived);
                }
                else{
                    IERC20(_collateralAsset).transfer(msg.sender, _tokenReceived);
                }
                emit lenderLiquidated(msg.sender, lender,_tokenReceived);
            }

        }

    }
    function correspondingBorrowTokens(uint256 _liquidityShares) public returns(uint256){
        uint256 _collateralTokens = IYield(investedTo).getTokensForShares(_liquidityShares, collateralAsset);
        uint256 _correspondingBorrowTokens = 
            _collateralTokens.mul(IPriceOracle(IPoolFactory(PoolFactory).priceOracle()).getLatestPrice(
                borrowAsset,
                collateralAsset
            )).mul(liquidatorRewardFraction).div(100);
    }


    function liquidatePool(bool _transferToSavingsAccount, bool _recieveLiquidityShare) external payable {
        LoanStatus _poolStatus = loanStatus;
        require(
            _poolStatus == LoanStatus.DEFAULTED || ((_poolStatus == LoanStatus.TERMINATED) && (matchCollateralRatioEndTime == 0)),
            "Pool::liquidateLender - Borrower Extra time to match collateral is running"
        );

        ISavingAccount _savingAccount = ISavingAccount(IPoolFactory(PoolFactory).SavingAccount());
     
        uint256 _amountToBeRepaid;
        address _collateralAsset = collateralAsset;
 
        uint256 _collateralLiquidityShare = baseLiquidityShares.add(extraLiquidityShares);  
        uint256 _correspondingBorrowTokens = correspondingBorrowTokens(_collateralLiquidityShare);

        if (borrowAsset == address(0)){
            if(msg.value<_correspondingBorrowTokens){
                revert("Pool::liquidatePool - Not enough tokens");
            }
        }
        else{
            IERC20(borrowAsset).transferFrom(
                msg.sender,
                address(this),
                _correspondingBorrowTokens
            );
        }
        uint256 _tokenReceived;
        if(_transferToSavingsAccount == true){
            uint256 _sharesReceived = _savingAccount.transfer(msg.sender, _collateralLiquidityShare, _collateralAsset, investedTo);
        }
        else{
            if(_recieveLiquidityShare == true){
                uint256 _sharesReceived = _savingAccount.transfer(msg.sender, _collateralLiquidityShare, _collateralAsset, investedTo);
                address _addressOfTheLiquidityToken = IYield(investedTo).liquidityToken(_collateralAsset);
                IERC20(_addressOfTheLiquidityToken).transfer(msg.sender, _sharesReceived);
            }
            else{
                uint256 _collateralTokens = IYield(investedTo).getTokensForShares(_collateralLiquidityShare, collateralAsset);
                _savingAccount.withdraw(_collateralTokens, _collateralAsset, investedTo, false);
                if(_collateralAsset == address(0)){
                    msg.sender.send(_collateralTokens);
                }
                else{
                    IERC20(_collateralAsset).transfer(msg.sender, _collateralTokens);
                }
            }
        }
        emit PoolLiquidated(msg.sender);
        
    }

    
    // Withdraw Repayment, Also all the extra state variables are added here only for the review

    function interestPerSecond(uint _principle) public view returns(uint256){
        
    }

    function amountLenderPerPeriod(address lender) public view returns(uint256){
        
    }

    function calculateCurrentPeriod() public view returns(uint256){
        
    }

    
    function withdrawRepayment() external payable {
        
    }

    function transferTokensRepayments(uint256 amount, address from, address to) internal{
        _withdrawRepayment(from);
        _withdrawRepayment(to);
        
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