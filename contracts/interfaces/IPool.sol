// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

interface IPool {
    enum LoanStatus {
        COLLECTION, //denotes collection period
        FUNDWITHDRAWAL,
        ACTIVE,
        CLOSED,
        CANCELLED,
        DEFAULTED,
        TERMINATED
    }

    function lend(address _lender, uint256 _amountLent) external;

    function deposit(address _lender, uint256 _amount) external payable;

    //Borrower
    function registerBorrower(address _borrower, bytes32 _offChainDetails)
        external;

    function updateBorrowerDetails(address _borrower, bytes32 _offChainDetails)
        external;
 
    function lockCollateral(bytes32 poolHash, uint256 amount) external;

    function addExtraCollateral(bytes32 poolHash, uint256 extraCollateralAmount)
        external;

    function withdrawBorrowedAmount(bytes32 poolHash) external;

    function requestExtension(bytes32 poolHash) external;

    function repayAmount(bytes32 poolHash, uint256 amount) external;

    function withdrawCollateral(bytes32 poolHash, uint256 amount) external;

    //Pool
    function cancelOpenBorrowPool(bytes32 poolHash) external;

    function terminateOpenBorrowPool(bytes32 poolHash) external;

    function closeLoan(bytes32 poolHash) external;

    function defaultLoan(bytes32 poolHash) external;

    function calculateLendingRate(uint256 s) external view returns (uint256);

    //Liquidation
    function getCurrentCollateralRatio(bytes32 poolHash, address lender)
        external
        view
        returns (uint256 ratio);

    function liquidatePool(bytes32 poolHash, address lender) external;

    //getters

    function getThreshold(bytes32 poolHash) external view returns(uint256);

    function getRepaymentAddress() external view returns (address);

    function getLenderAddress() external view returns (address);

    function getIfExists(bytes32 poolHash) external returns (bool);

    function getPoolOwner(bytes32 poolHash) external returns (address);

    function getPoolSize(bytes32 poolHash) external returns (uint256);

    function getLoanStartedAt(bytes32 poolHash) external returns (uint256);

    function getBorrowTokenType(bytes32 poolHash) external returns (address);

    function getBorrowTokensCollected(bytes32 poolHash)
        external
        returns (uint256);

    function getCollateralTokenType(bytes32 poolHash)
        external
        returns (address);

    function getCollateralDeposited(bytes32 poolHash)
        external
        returns (uint256);

    function getBorrowRate(bytes32 poolHash) external returns (uint256);

    function getLoanDuration(bytes32 poolHash) external returns (uint256);

    function getCollateralRatio(bytes32 poolHash) external returns (uint256);

    function getLoanStatus(bytes32 poolHash) external returns (LoanStatus);

    function getCollateralCalls(bytes32 poolHash) external returns (uint256);

    function getTotalVotes(bytes32 poolHash) external returns (uint256);

    function getLiquidityShares(bytes32 poolHash) external returns (uint256);

    function getInvestedTo(bytes32 poolHash) external returns (address);

    function getIntervalToAddExtraCollateral(bytes32 poolHash)
        external
        returns (uint256);

    //setters
    function transferLenderImpl(address lenderImpl) external;

    function transferRepayImpl(address repayImpl) external;

    function setIfExists(bytes32 poolHash, bool exists) external;

    function setPoolOwner(bytes32 poolHash, address poolOwner) external;

    function setPoolSize(bytes32 poolHash, uint256 poolSize) external;

    function setLoanStartedAt(bytes32 poolHash, uint256 loanStartedAt) external;

    function setBorrowTokenType(bytes32 poolHash, address borrowTokenType)
        external;

    function setBorrowTokensCollected(
        bytes32 poolHash,
        uint256 borrowTokensCollected
    ) external;

    function setCollateralTokenType(
        bytes32 poolHash,
        address collateralTokenType
    ) external;

    function setCollateralDeposited(
        bytes32 poolHash,
        uint256 collateralDeposited
    ) external;

    function setBorrowRate(bytes32 poolHash, uint256 borrowRate) external;

    function setLoanDuration(bytes32 poolHash, uint256 loanDuration) external;

    function setCollateralRatio(bytes32 poolHash, uint256 collateralRatio)
        external;

    function setLoanStatus(bytes32 poolHash, LoanStatus loanStatus) external;

    function setCollateralCalls(bytes32 poolHash, uint256 collateralCalls)
        external;

    function setTotalVotes(bytes32 poolHash, uint256 totalVotes) external;

    function setLiquidityShares(bytes32 poolHash, uint256 liquidityShares)
        external;

    function setInvestedTo(bytes32 poolHash, address investedTo) external;

    function setIntervalToAddExtraCollateral(
        bytes32 poolHash,
        uint256 intervalToAddExtraCollateral
    ) external;

    function setThreshold(bytes32 poolHash, uint256 threshold) external;
}
