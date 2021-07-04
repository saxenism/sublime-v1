// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

interface IRepayment {
    function initializeRepayment(
        uint256 numberOfTotalRepayments,
        uint256 repaymentInterval,
        uint256 borrowRate,
        uint256 loanStartTime,
        address lentAsset
    ) external;

    /*
    function calculateRepayAmount(address poolID)
        external
        view
        returns (uint256);
    */

    function getTotalRepaidAmount(address poolID)
        external
        view
        returns (uint256);

    //function getRepaymentPeriodCovered(address poolID) external view returns(uint256);
    //function getRepaymentOverdue(address poolID) external view returns(uint256);
    //function repaymentExtended(address poolID) external;

    function getInterestCalculationVars(address poolID)
        external
        view
        returns (uint256, uint256);

    //function getOngoingLoanInterval(address poolID) external view returns(uint256);

    function getCurrentLoanInterval(address poolID)
        external
        view
        returns (uint256);

    function instalmentDeadlineExtended(address _poolID, uint256 _period)
        external;

    function didBorrowerDefault(address _poolID) external view returns (bool);
}
