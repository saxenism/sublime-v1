// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract StrategyRegistry is Initializable, OwnableUpgradeable {

    mapping(address => bool) public registry;

    event StrategyAdded(address strategy);
    event StrategyRemoved(address strategy);

    function initialize(address _owner) public initializer {
        __Ownable_init();
        super.transferOwnership(_owner);
    }

    function addStrategy(address _strategy) external onlyOwner {
        registry[_strategy] = true;
        emit StrategyAdded(_strategy);
    }

    function removeStrategy(address _strategy) external onlyOwner {
        delete registry[_strategy];
        emit StrategyRemoved(_strategy);
    }
}