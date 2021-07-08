// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface ILender {
    function transferPoolImpl(address poolImpl) external;

    function transferRepayImpl(address repayImpl) external;

    function getPoolImpl() external returns (address);

    function getRepayImpl() external returns (address);

    function supplyLiquidity(
        address lenderAddress,
        bytes32 poolHash,
        uint256 amountSupplied
    ) external payable;

    function withdrawLiquidity(bytes32 poolHash, address lenderAddress) external;

    function withdrawInterest(
        bytes32 poolHash,
        address lenderAddress,
        uint256 amount
    ) external;

    function withdrawRepayment(bytes32 poolHash, uint256 amountWantToWithdraw) external payable;

    function getResultOfVoting(bytes32 poolHash) external view returns (uint256);

    function requestCollateralCall(bytes32 poolHash) external;

    function voteOnExtension(bytes32 poolHash) external;

    function ResultOfVoting(bytes32 poolHash) external;

    function borrow(bytes32 poolHash, address borrower) external returns (uint256);

    //getters
    function getAmountSupplied(bytes32 poolHash, address lender) external view returns (uint256);

    function getPercentWithdrawable(bytes32 poolHash, address lender) external view returns (uint256);

    function getAmountWithrawn(bytes32 poolHash, address lender) external view returns (uint256);

    function getAmountWithrawable(bytes32 poolHash, address lender) external view returns (uint256);

    function getExtraCollateralDueBlock(bytes32 poolHash, address lender) external view returns (uint256);

    function getExists(bytes32 poolHash, address lender) external view returns (bool);

    function getVotedOnExtension(bytes32 poolHash, address lender) external view returns (bool);

    function getDefaultVote(bytes32 poolHash, address lender) external view returns (bool);

    function getCollateralCalled(bytes32 poolHash, address lender) external view returns (bool);

    //setters
    function setAmountSupplied(
        bytes32 poolHash,
        address lender,
        uint256 newVal
    ) external;

    function setAmountWithrawn(
        bytes32 poolHash,
        address lender,
        uint256 newVal
    ) external;

    function setAmountWithrawable(
        bytes32 poolHash,
        address lender,
        uint256 newVal
    ) external;

    function setExtraCollateralDueBlock(
        bytes32 poolHash,
        address lender,
        uint256 newVal
    ) external;

    function setExists(
        bytes32 poolHash,
        address lender,
        bool newVal
    ) external;

    function setVotedOnExtension(
        bytes32 poolHash,
        address lender,
        bool newVal
    ) external;

    function setDefaultVote(
        bytes32 poolHash,
        address lender,
        bool newVal
    ) external;

    function setCollateralCalled(
        bytes32 poolHash,
        address lender,
        bool newVal
    ) external;
}
