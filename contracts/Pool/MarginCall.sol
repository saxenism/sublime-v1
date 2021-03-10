// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IPoolFactory.sol";

contract MarginCall is Initializable {

	enum LoanStatus {
        COLLECTION, //denotes collection period
        ACTIVE, // denotes the active loan
        CLOSED, // Loan is repaid and closed
        CANCELLED, // Cancelled by borrower
        DEFAULTED, // Repaymennt defaulted by  borrower
        TERMINATED // Pool terminated by admin
    }

    struct 

	poolVars.loanStatus
	lenders[_lender].marginCallEndTime
	poolID
	poolVars.extraLiquidityShares
	lenders[_lender].extraLiquidityShares
	poolConstants.collateralRatio
	poolConstants.matchCollateralRatioEndTime



	event MarginCallCollateralAdded(address borrower, address lender, uint256 amount, uint256 sharesReceived);


	function addCollateralInMarginCall (address _lender, uint256 _amount, bool _transferFromSavingsAccount) 
		external payable override {

        require(poolVars.loanStatus == LoanStatus.ACTIVE,
            	"Pool::addCollateralMarginCall - Loan needs to be in Active stage to deposit");

        require(lenders[_lender].marginCallEndTime >= block.timestamp,
             	"Pool::addCollateralMarginCall - Can't Add after time is completed");

        require(_amount != 0,
            	"Pool::addCollateralMarginCall - collateral amount");

        uint256 _sharesReceived = _depositToSavingsAccount(_transferFromSavingsAccount, poolConstants.collateralAsset, _amount, poolConstants.investedTo, address(this), msg.sender);

        poolVars.extraLiquidityShares = poolVars.extraLiquidityShares.add(_sharesReceived);

        lenders[_lender].extraLiquidityShares = lenders[_lender].extraLiquidityShares.add(_sharesReceived);

        // TODO: If collateral goes above the expected collateral, delete marginCallEndTime variable
        if(getCurrentCollateralRatio(_lender) >= poolConstants.collateralRatio) {
            delete lenders[_lender].marginCallEndTime;
        }

        emit MarginCallCollateralAdded(msg.sender, _lender, _amount, _sharesReceived);
    }


    function requestMarginCall() external isPoolActive isLender(msg.sender) {
        require(
            lenders[msg.sender].marginCallEndTime < block.timestamp,
            "Pool::requestMarginCall margin call already requested"
        );

        require(
            poolConstants.collateralRatio >
                getCurrentCollateralRatio(msg.sender).add(
                    IPoolFactory(PoolFactory).collateralVolatilityThreshold()
                ),
            "Pool::requestMarginCall collateral ratio has not reached threshold yet"
        );

        lenders[msg.sender].marginCallEndTime = block.timestamp.add(
            IPoolFactory(PoolFactory).marginCallDuration()
        );

        emit CollateralCalled(msg.sender);
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
                "Pool::liquidateLender - Borrower Extra time to match collateral is running"
            );
            uint256 _marginCallEndTime = lenders[lender].marginCallEndTime;
            require(_marginCallEndTime != 0, "No margin call has been called.");
            require(
                _marginCallEndTime < block.timestamp,
                "Pool::liquidateLender - period for depositing extra collateral not ended"
            );

            require(
                poolConstants.collateralRatio.sub(
                    IPoolFactory(PoolFactory).collateralVolatilityThreshold()
                ) > getCurrentCollateralRatio(lender),
                "Pool::liquidateLender - collateral ratio has not reached threshold yet"
            );
            require(
                poolToken.balanceOf(lender) != 0,
                "The user has already transferred all this tokens."
            );
        }
        ISavingsAccount _savingAccount =
            ISavingsAccount(IPoolFactory(PoolFactory).savingsAccount());

        address _collateralAsset = poolConstants.collateralAsset;
        address _investedTo = poolConstants.investedTo;
        uint256 _lenderBalance = poolToken.balanceOf(lender);
        uint256 _collateralLiquidityShare =
            ((poolVars.baseLiquidityShares.mul(_lenderBalance)).div(poolToken.totalSupply()))
                .add(lenders[lender].extraLiquidityShares);
        uint256 _collateralTokens =
            IYield(_investedTo).getTokensForShares(
                _collateralLiquidityShare,
                _collateralAsset
            );

        {
            uint256 _correspondingBorrowTokens = correspondingBorrowTokens(_collateralLiquidityShare);
            address _borrowAsset = poolConstants.borrowAsset;
            uint256 _sharesReceived;
            if (_borrowAsset == address(0)) {
                if (msg.value < _correspondingBorrowTokens) {
                    revert("Pool::liquidateLender - Not enough tokens");
                }
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
        emit lenderLiquidated(msg.sender, lender, _amountReceived);
    }


}