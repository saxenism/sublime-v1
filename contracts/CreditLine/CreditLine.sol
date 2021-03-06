// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./CreditLineStorage.sol";
import "../interfaces/IPoolFactory.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IYield.sol";
import "../interfaces/IRepayment.sol";
import "../interfaces/ISavingsAccount.sol";
import "../interfaces/IStrategyRegistry.sol";

/**
 * @title Credit Line contract with Methods related to credit Line
 * @notice Implements the functions related to Credit Line
 * @author Sublime
 **/



contract CreditLine is CreditLineStorage {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public PoolFactory;
    address public strategyRegistry;

    /**
     * @dev checks if Credit Line exists
     * @param creditLineHash credit hash
     **/
    modifier ifCreditLineExists(bytes32 creditLineHash) {
        require(
            creditLineInfo[creditLineHash].exists == true,
            "Credit line does not exist"
        );
        _;
    }

    /**
     * @dev checks if called by credit Line Borrower
     * @param creditLineHash creditLine Hash
     **/
    modifier onlyCreditLineBorrower(bytes32 creditLineHash) {
        require(
            creditLineInfo[creditLineHash].borrower == msg.sender,
            "Only credit line Borrower can access"
        );
        _;
    }

    /**
     * @dev checks if called by credit Line Lender
     * @param creditLineHash creditLine Hash
     **/
    modifier onlyCreditLineLender(bytes32 creditLineHash) {
        require(
            creditLineInfo[creditLineHash].lender == msg.sender,
            "Only credit line Lender can access"
        );
        _;
    }


    /**
     * @dev emits when borrower request for a credit Line
     * @param creditLineHash the credit Line Hash
     **/
    event CreditLineRequestedToLender(bytes32 creditLineHash, address lender, address borrower);
    event CreditLineRequestedToBorrower(bytes32 creditLineHash, address lender, address borrower);


    function initialize() public initializer {
        __Ownable_init();
    }


    /**
     * @dev Used to Calculate Interest Per second on given principal and Interest rate
     * @param principal principal Amount for which interest has to be calculated.
     * @param borrowRate It is the Interest Rate at which Credit Line is approved
    * @return uint256 interest per second for the given parameters
    */
    function calculateInterestPerSecond(uint256 principal, uint256 borrowRate)
        public
        view
        returns (uint256)
    {
        uint256 _interest = (principal.mul(borrowRate)).div(yearSeconds);
        return _interest;
    }


    /**
     * @dev Used to calculate interest accrued since last repayment
     * @param creditLineHash Hash of the credit line for which interest accrued has to be calculated
     * @return uint256 interest accrued over current borrowed amount since last repayment
    */

    function calculateInterestAccrued(bytes32 creditLineHash)
        public
        view
        ifCreditLineExists(creditLineHash)
        returns (uint256)
    {
        uint256 timeElapsed = block.timestamp - creditLineUsage[creditLineHash].lastPrincipalUpdateTime;

        uint256 interestAccrued = calculateInterestPerSecond(
                                        creditLineUsage[creditLineHash].principal,
                                        creditLineInfo[creditLineHash].borrowRate
                                    ).mul(timeElapsed);
        return interestAccrued;
    }

    /**
     * @dev Used to calculate current debt of borrower against a credit line. 
     * @param creditLineHash Hash of the credit line for which current debt has to be calculated
     * @return uint256 current debt of borrower 
    */

    // maybe change interestAccruedTillPrincipalUpdate to interestAccruedTillLastPrincipalUpdate
    function calculateCurrentDebt(bytes32 creditLineHash)
        public
        view
        ifCreditLineExists(creditLineHash)
        returns (uint256)
    {
        uint256 interestAccrued = calculateInterestAccrued(creditLineHash);
        uint256 currentDebt =
            (creditLineUsage[creditLineHash].principal)
                .add(creditLineUsage[creditLineHash].interestAccruedTillPrincipalUpdate)
                .add(interestAccrued)
                .sub(creditLineUsage[creditLineHash].totalInterestRepaid);
        return currentDebt;
    }

    function updateinterestAccruedTillPrincipalUpdate(bytes32 creditLineHash)
        internal
        ifCreditLineExists(creditLineHash)
        returns (uint256) {

            require(creditLineInfo[creditLineHash].currentStatus == creditLineStatus.ACTIVE,
                "CreditLine: The credit line is not yet active.");

            uint256 interestAccrued = calculateInterestAccrued(creditLineHash);
            uint256 newInterestAccrued = (creditLineUsage[creditLineHash].interestAccruedTillPrincipalUpdate)
                                            .add(interestAccrued);
            creditLineUsage[creditLineHash].interestAccruedTillPrincipalUpdate = newInterestAccrued;

            return newInterestAccrued;
        }

    /**
     * @dev used to request a credit line by a borrower
     * @param lender lender from whom creditLine is requested
     * @param borrowLimit maximum borrow amount in a credit line
     * @param liquidationThreshold threshold for liquidation 
     * @param borrowRate Interest Rate at which credit Line is requested
    */
    function requestCreditLineToLender(
        address lender,
        uint256 borrowLimit,
        uint256 liquidationThreshold,
        uint256 borrowRate,
        bool autoLiquidation,
        uint256 collateralRatio,
        address borrowAsset,
        address collateralAsset
    ) public returns (bytes32) {

        //require(userData[lender].blockCreditLineRequests == true,
        //        "CreditLine: External requests blocked");

        CreditLineCounter = CreditLineCounter + 1; // global counter to generate ID

        bytes32 creditLineHash = keccak256(abi.encodePacked(CreditLineCounter));
        CreditLineVars memory temp;

        temp.exists = true;
        temp.currentStatus = creditLineStatus.REQUESTED;
        temp.borrower = msg.sender;
        temp.lender = lender;
        temp.borrowLimit = borrowLimit;
        temp.autoLiquidation = autoLiquidation;
        temp.idealCollateralRatio = collateralRatio;
        temp.liquidationThreshold = liquidationThreshold;
        temp.borrowRate = borrowRate;
        temp.borrowAsset = borrowAsset;
        temp.collateralAsset = collateralAsset;

        creditLineInfo[creditLineHash] = temp;
        // setRepayments(creditLineHash);
        emit CreditLineRequestedToLender(creditLineHash, lender, msg.sender);

        return creditLineHash;

    }

    function requestCreditLineToBorrower(
        address borrower,
        uint256 borrowLimit,
        uint256 liquidationThreshold,
        uint256 borrowRate,
        bool autoLiquidation,
        uint256 collateralRatio,
        address borrowAsset,
        address collateralAsset
    ) public returns (bytes32) {

        //require(userData[borrower].blockCreditLineRequests == true,
        //        "CreditLine: External requests blocked");

        CreditLineCounter = CreditLineCounter + 1; // global counter to generate ID

        bytes32 creditLineHash = keccak256(abi.encodePacked(CreditLineCounter));
        CreditLineVars memory temp;

        temp.exists = true;
        temp.currentStatus = creditLineStatus.REQUESTED;
        temp.borrower = borrower;
        temp.lender = msg.sender;
        temp.borrowLimit = borrowLimit;
        temp.autoLiquidation = autoLiquidation;
        temp.idealCollateralRatio = collateralRatio;
        temp.liquidationThreshold = liquidationThreshold;
        temp.borrowRate = borrowRate;
        temp.borrowAsset = borrowAsset;
        temp.collateralAsset = collateralAsset;

        creditLineInfo[creditLineHash] = temp;
        // setRepayments(creditLineHash);
        emit CreditLineRequestedToBorrower(creditLineHash, msg.sender, borrower);

        return creditLineHash;

    }


    event CreditLineAccepted(bytes32 creditLineHash);
    /**
     * @dev used to Accept a credit line by a specified lender
     * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    */
    function acceptCreditLine(bytes32 creditLineHash)
        external
        ifCreditLineExists(creditLineHash)
        onlyCreditLineLender(creditLineHash)
    {
        require(
            creditLineInfo[creditLineHash].currentStatus == creditLineStatus.REQUESTED,
            "CreditLine is already accepted");

        creditLineInfo[creditLineHash].currentStatus = creditLineStatus.ACTIVE;

        emit CreditLineAccepted(creditLineHash);
    }


  
    // /**
    //  * @dev used to withdraw assest from credit line 
    //  * @param borrowAmount amount which borrower wants to withdraw from credit line
    //  * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    // */

    function transferFromTo(address _asset, uint256 _amount, bytes32 creditLineHash, address sender, address recipient) internal {

        address[] memory _strategyList = IStrategyRegistry(strategyRegistry).getStrategies();
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        uint256 _activeAmount;
        uint256 liquidityShares;

        for (uint256 index = 0; index < _strategyList.length; index++) {
            liquidityShares = _savingAccount.userLockedBalance(sender, _asset, _strategyList[index]);
            if (liquidityShares > 0) {
                uint256 _tokenInStrategy = IYield(_strategyList[index]).getTokensForShares(liquidityShares, _asset);
                _activeAmount = _activeAmount.add(_tokenInStrategy);
                if(_activeAmount>_amount){
                    uint256 _remainingliquidityShares = (_activeAmount.sub(_amount)).mul(liquidityShares).div(_tokenInStrategy);
                    _savingAccount.transferFrom(_asset, sender, recipient, _strategyList[index], _remainingliquidityShares);
                    collateralShareInStrategy[creditLineHash][_strategyList[index]] = collateralShareInStrategy[creditLineHash][_strategyList[index]].add(_remainingliquidityShares);
                    return;
                }
                else{
                    _savingAccount.transferFrom(_asset, sender, recipient, _strategyList[index], liquidityShares);
                    collateralShareInStrategy[creditLineHash][_strategyList[index]] = collateralShareInStrategy[creditLineHash][_strategyList[index]].add(liquidityShares);
                }   
            }
        }
        require(_activeAmount >= _amount,"insufficient balance");
    }

    function _depositCollateral(address _collateralAsset,uint256 _collateralAmount, address strategy, bytes32 creditLineHash,bool _transferCollateralFromSavingAccount) internal payable{

        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        uint256 _sharesReceived;
        if(_transferCollateralFromSavingAccount){
            transferFromTo(_collateralAsset,_collateralAmount, creditLineHash, msg.sender, address(this));
        }
        else{
            if(_collateralAsset == address(0)){
                require(msg.value == _collateralAmount, "CreditLine ::borrowFromCreditLine - value to transfer doesn't match argument");
                _sharesReceived = _savingAccount.deposit{value:msg.value}(_collateralAmount,_collateralAsset,strategy, address(this));
            }
            else{                
                _sharesReceived = _savingAccount.deposit(_collateralAmount,_collateralAsset, strategy, address(this));
            }
            collateralShareInStrategy[creditLineHash][strategy] = collateralShareInStrategy[creditLineHash][strategy].add(_sharesReceived);
        }

    }

    function _withdrawAmount(address _asset, uint256 _amountInTokens, bytes32 creditLineHash) internal {

        address _lender = creditLineInfo[creditLineHash].lender;
        address[] memory _strategyList = IStrategyRegistry(strategyRegistry).getStrategies();
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        uint amount;
        uint256 liquidityShares;
        for (uint256 index = 0; index < _strategyList.length; index++) {
            liquidityShares = _savingAccount.userLockedBalance(msg.sender, _asset, _strategyList[index]);
            if (liquidityShares > 0) {
                uint256 tokenInStrategy = IYield(_strategyList[index]).getTokensForShares(liquidityShares, _asset);
                amount = amount.add(tokenInStrategy);
                if(amount>_amountInTokens){
                    uint256 remainingliquidityShares = (amount.sub(_amountInTokens)).mul(liquidityShares).div(tokenInStrategy);
                    _savingAccount.withdraw(msg.sender,remainingliquidityShares, _asset, _strategyList[index], false);
                    return;
                }
                else{
                    _savingAccount.withdraw(msg.sender,liquidityShares, _asset, _strategyList[index], false);
                }   
            }
        }
        require(amount >= _amountInTokens,"insufficient balance");
    }



    event BorrowedFromCreditLine(uint256 borrowAmount, bytes32 creditLineHash);

    function borrowFromCreditLine(uint256 borrowAmount, bytes32 creditLineHash,bool _transferCollateralFromSavingAccount,uint256 _collateralAmount)
        external payable
        ifCreditLineExists(creditLineHash)
        onlyCreditLineBorrower(creditLineHash)
    {   
        require(creditLineInfo[creditLineHash].currentStatus == creditLineStatus.ACTIVE,
                "CreditLine: The credit line is not yet active.");

        uint256 _currentDebt = calculateCurrentDebt(creditLineHash);
        require(
            _currentDebt.add(borrowAmount) <= creditLineInfo[creditLineHash].borrowLimit,
            "CreditLine: Amount exceeds borrow limit.");

        address _defaultStrategy = IStrategyRegistry(strategyRegistry).getStrategies()[0];
        address _collateralAsset = creditLineInfo[creditLineHash].collateralAsset;        
        _depositCollateral(_collateralAsset, _collateralAmount, _defaultStrategy,creditLineHash,_transferCollateralFromSavingAccount);



        uint256 interestAccruedTillPrincipalUpdate = updateinterestAccruedTillPrincipalUpdate(creditLineHash);

        //refactor
        creditLineUsage[creditLineHash].principal = creditLineUsage[creditLineHash].principal.add(borrowAmount);
        creditLineUsage[creditLineHash].lastPrincipalUpdateTime = block.timestamp;

        _withdrawAmount(creditLineInfo[creditLineHash].borrowAsset, borrowAmount,creditLineHash);
        if(creditLineInfo[creditLineHash].borrowAsset==address(0)){
            msg.sender.transfer(borrowAmount);
        }
        else{
            IERC20(creditLineInfo[creditLineHash].borrowAsset).transfer(msg.sender, borrowAmount);
        }
        /// transfer of assest is remaning as it requires interation with saving account of lender
        emit BorrowedFromCreditLine(borrowAmount, creditLineHash);
    }


    //TODO:- Make the function to accept ether as well 
    /**
     * @dev used to repay assest to credit line 
     * @param repayAmount amount which borrower wants to repay to credit line
     * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    */

    /*
        Parameters used:
        - currentStatus
        - borrowAsset
        - interestAccruedTillPrincipalUpdate
        - principal
        - totalInterestRepaid
        - lastPrincipalUpdateTime



    */



    event PartialCreditLineRepaid(bytes32 creditLineHash, uint256 repayAmount);

    function repayCreditLine(uint256 repayAmount, bytes32 creditLineHash, address asset, bool _transferFromSavingAccount)
        external
        ifCreditLineExists(creditLineHash)
        onlyCreditLineBorrower(creditLineHash)
    {   

        require(creditLineInfo[creditLineHash].currentStatus == creditLineStatus.ACTIVE,
                "CreditLine: The credit line is not yet active.");
        // update 

        require(asset == creditLineInfo[creditLineHash].borrowAsset,
                "CreditLine: Asset does not match.");
                
        address _borrowAsset = creditLineInfo[creditLineHash].borrowAsset;
        address _lender = creditLineInfo[creditLineHash].lender;
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        address _defaultStrategy = IStrategyRegistry(strategyRegistry).getStrategies()[0];
        uint256 _sharesReceived;
        if(_transferFromSavingAccount == false){
            if(_borrowAsset == address(0)){
                require(msg.value == repayAmount, "Pool::deposit - value to transfer doesn't match argument");
                _sharesReceived = _savingAccount.deposit{value:msg.value}(repayAmount,_borrowAsset, _defaultStrategy, address(this));
            }
            else{
                _sharesReceived = _savingAccount.deposit(repayAmount, _borrowAsset, _defaultStrategy, address(this));
            }

            _savingAccount.transfer(_borrowAsset, _lender, _defaultStrategy, _sharesReceived);
        }
        else{
            transferFromTo(_borrowAsset, repayAmount, creditLineHash, msg.sender, _lender);
        }


        uint256 _interestSincePrincipalUpdate = calculateInterestAccrued(creditLineHash);
        uint256 _totalInterestAccrued = (creditLineUsage[creditLineHash].interestAccruedTillPrincipalUpdate)
                                        .add(_interestSincePrincipalUpdate);

        uint256 _totalDebt = _totalInterestAccrued.add(creditLineUsage[creditLineHash].principal);
        // check requried for correct token type
        //uint256 _currentDebt = calculateCurrentDebt(creditLineHash);
        require(_totalDebt >= repayAmount,
                "CreditLine: Repay amount is greater than debt.");

        if (repayAmount.add(creditLineUsage[creditLineHash].totalInterestRepaid) <= _totalInterestAccrued) {
            creditLineUsage[creditLineHash].totalInterestRepaid = repayAmount
                                                                .add(creditLineUsage[creditLineHash].totalInterestRepaid);
        }
        else {
            creditLineUsage[creditLineHash].principal = (creditLineUsage[creditLineHash].principal)
                                                        .sub(repayAmount)
                                                        .sub(creditLineUsage[creditLineHash].totalInterestRepaid)
                                                        .add(_totalInterestAccrued);
            creditLineUsage[creditLineHash].interestAccruedTillPrincipalUpdate = _totalInterestAccrued;
            creditLineUsage[creditLineHash].totalInterestRepaid = repayAmount
                                                            .add(creditLineUsage[creditLineHash].totalInterestRepaid);
            creditLineUsage[creditLineHash].lastPrincipalUpdateTime = block.timestamp;
        }

        /// TODO - make the transfer

        if (creditLineUsage[creditLineHash].principal == 0) {
            _resetCreditLine(creditLineHash);
        }

        // emit event

        PartialCreditLineRepaid(creditLineHash, repayAmount);
    }


    event CreditLineReset(bytes32 creditLineHash);

    function _resetCreditLine(bytes32 creditLineHash) 
        internal 
        ifCreditLineExists(creditLineHash) {

        require(creditLineInfo[creditLineHash].currentStatus == creditLineStatus.ACTIVE,
                "CreditLine: Credit line should be active.");

        creditLineUsage[creditLineHash].lastPrincipalUpdateTime = 0; // check if can assign 0 or not
        creditLineUsage[creditLineHash].totalInterestRepaid = 0;
        creditLineUsage[creditLineHash].interestAccruedTillPrincipalUpdate = 0;

        emit CreditLineReset(creditLineHash);
    }

    /**
     * @dev used to close credit line once by borrower or lender  
     * @param creditLineHash Credit line hash which represents the credit Line Unique Hash
    */

    event CreditLineClosed(bytes32 creditLineHash);

    function closeCreditLine(bytes32 creditLineHash)
        external
        ifCreditLineExists(creditLineHash)
    {
        require(
            msg.sender == creditLineInfo[creditLineHash].borrower ||
                msg.sender == creditLineInfo[creditLineHash].lender,
            "CreditLine: Permission denied while closing Line of credit"
        );

        require(creditLineInfo[creditLineHash].currentStatus == creditLineStatus.ACTIVE,
                "CreditLine: Credit line should be active.");

        require(creditLineUsage[creditLineHash].principal == 0,
                "CreditLine: Cannot be closed since not repaid.");

        require(creditLineUsage[creditLineHash].interestAccruedTillPrincipalUpdate == 0,
                "CreditLine: Cannot be closed since not repaid.");

        creditLineInfo[creditLineHash].currentStatus = creditLineStatus.CLOSED;

        // emit event
        emit CreditLineClosed(creditLineHash);
    }



    function calculateCurrentCollateralRatio(bytes32 creditLineHash) 
        public 
        view 
        ifCreditLineExists(creditLineHash) returns (uint256) {

        uint256 _ratioOfPrices =
            IPriceOracle(IPoolFactory(PoolFactory).priceOracle())
                .getLatestPrice(
                creditLineInfo[creditLineHash].collateralAsset,
                creditLineInfo[creditLineHash].borrowAsset);

        uint256 currentDebt = calculateCurrentDebt(creditLineHash);
        uint256 currentCollateralRatio = ((creditLineUsage[creditLineHash].collateralAmount)
                                            .div(currentDebt)).mul(_ratioOfPrices);

        return currentCollateralRatio;
    }


    function calculateTotalCollateralTokens(bytes32 creditLineHash) public returns(uint256 amount){
        address _collateralAsset = creditLineInfo[creditLineHash].collateralAsset;
        address[] memory _strategyList = IStrategyRegistry(strategyRegistry).getStrategies();
        ISavingsAccount _savingAccount = ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());
        uint256 liquidityShares;
        for (uint256 index = 0; index < _strategyList.length; index++) {
            liquidityShares = collateralShareInStrategy[creditLineHash][_strategyList[index]];
            uint256 tokenInStrategy = IYield(_strategyList[index]).getTokensForShares(liquidityShares, _collateralAsset);
            amount = amount.add(tokenInStrategy);
        }   
    }


    function liquidation(bytes32 creditLineHash) 
        external payable
        ifCreditLineExists(creditLineHash) 
    {
        require(creditLineInfo[creditLineHash].currentStatus == creditLineStatus.ACTIVE,
                "CreditLine: Credit line should be active.");

        uint currentCollateralRatio = calculateCurrentCollateralRatio(creditLineHash);

        require(currentCollateralRatio < creditLineInfo[creditLineHash].liquidationThreshold,
                "CreditLine: Collateral ratio is higher than liquidation threshold");
        

        address _collateralAsset = creditLineInfo[creditLineHash].collateralAsset;
        address _lender = creditLineInfo[creditLineHash].lender;
        uint256 _totalCollateralToken = calculateTotalCollateralTokens(creditLineHash);

        if(creditLineInfo[creditLineHash].autoLiquidation) {
            
            _withdrawAmount(_collateralAsset, _totalCollateralToken,creditLineHash);
            if(_collateralAsset==address(0)){
                msg.sender.transfer(_totalCollateralToken);
            }
            else{
                IERC20(_collateralAsset).transfer(msg.sender, _totalCollateralToken);
            }   
        }
        else {

            require(msg.sender == creditLineInfo[creditLineHash].lender,"CreditLine: Liquidation can only be performed by lender.");
            transferFromTo(_collateralAsset, _totalCollateralToken, creditLineHash, address(this), msg.sender);
        }

        delete creditLineInfo[creditLineHash];
    }






    // Think about threshHold liquidation 
    // only one type of token is accepted check for that
    // collateral ratio has to calculated initially
    // current debt is more than borrow amount
}
