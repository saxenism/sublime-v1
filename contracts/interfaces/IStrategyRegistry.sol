// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

interface IStrategyRegistry {
    function registry(address _strategy) external view returns(bool);
    function addStrategy(address _strategy) external;
    function removeStrategy(address _strategy) external;
}