// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface IStrategyRegistry {
    event StrategyAdded(address strategy);
    event StrategyRemoved(address strategy);

    function registry(address _strategy) external view returns (bool);
    function getStrategies() external view returns (address[] memory);

    /**
     * @dev Add strategies to invest in. Please ensure that number of strategies are less than maxStrategies.
     * @param _strategy address of the owner of the savings account contract
     **/
    function addStrategy(address _strategy) external;

    /**
     * @dev Remove strategy to invest in.
     * @param _strategyIndex Index of the strategy to remove
     **/
    function removeStrategy(uint256 _strategyIndex) external;

    /**
     * @dev Update strategy to invest in.
     * @param _strategyIndex Index of the strategy to remove
     * @param _oldStrategy Strategy that is to be removed
     * @param _newStrategy Updated strategy
     **/
    function updateStrategy(
        uint256 _strategyIndex,
        address _oldStrategy,
        address _newStrategy
    ) external;
}