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

    struct MarginCallVars {
        uint256 marginCallEndTime;
        address collateralAsset;
        address investedTo;
        uint256 poolCollateralRatio;
    }

    MarginCallVars marginCallVars;

	poolVars.loanStatus
	//lenders[_lender].marginCallEndTime
	poolID
	//poolVars.extraLiquidityShares
	//lenders[_lender].extraLiquidityShares
	poolConstants.collateralRatio // Need Library for this
	poolConstants.matchCollateralRatioEndTime // 



	event MarginCallCollateralAdded(address borrower, address lender, uint256 amount, uint256 sharesReceived);


	function addCollateralInMarginCall (address _pool, address _lender, uint256 _amount, bool _transferFromSavingsAccount) 
		external payable override {

        IPool pool = IPool(_pool);

        uint256 _marginCallEndTime = pool.getMarginCallEndTime(); // needs args
        uint256 _extraPoolLiquidityShares = pool.getExtraPoolLiquidityShares(); // needs args
        uint256 _extraLenderLiquidityShares = pool.getExtraLenderPoolLiquidityShares(); // needs args

        require(poolVars.loanStatus == LoanStatus.ACTIVE,
            	"Pool::addCollateralMarginCall - Loan needs to be in Active stage to deposit"); // need to handle loan status

        require(_marginCallEndTime >= block.timestamp,
             	"Pool::addCollateralMarginCall - Can't Add after time is completed");

        require(_amount != 0,
            	"Pool::addCollateralMarginCall - collateral amount");

        uint256 _sharesReceived = _depositToSavingsAccount(_transferFromSavingsAccount, marginCallVars.collateralAsset, _amount, marginCallVars.investedTo, _pool, msg.sender);

        _extraPoolLiquidityShares = _extraPoolLiquidityShares.add(_sharesReceived);

        updateExtraPoolLiquidityShares(); // needs args

        _extraLenderLiquidityShares = _extraLenderLiquidityShares.add(_sharesReceived);

        updateExtraLenderPoolLiquidityShares(); // needs args

        // TODO: If collateral goes above the expected collateral, delete marginCallEndTime variable
        if(getCurrentCollateralRatio(_lender) >= marginCallVars.poolCollateralRatio) {
            delete marginCallVars[].marginCallEndTime; //needs args
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


    


}