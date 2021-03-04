// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract StrategyRegistry is Initializable, OwnableUpgradeable {
    using SafeMath for uint256;

    address[] strategies;
    uint256 maxStrategies;

    event StrategyAdded(address strategy);
    event StrategyRemoved(address strategy);

    function initialize(address _owner, uint256 _maxStrategies)
        public
        initializer
    {
        require(
            _maxStrategies != 0,
            "StrategyRegistry::initialize maxStrategies cannot be zero"
        );
        __Ownable_init();
        super.transferOwnership(_owner);

        maxStrategies = _maxStrategies;
    }

    /**
     * @dev Add strategies to invest in. Please ensure that number of strategies are less than maxStrategies.
     * @param _strategy address of the owner of the savings account contract
     **/
    function addStrategy(address _strategy) external onlyOwner {
        require(
            strategies.length.add(1) <= maxStrategies,
            "StrategyRegistry::addStrategy - Can't add more strategies"
        );
        strategies.push(_strategy);

        emit StrategyAdded(_strategy);
    }

    /**
     * @dev Remove strategy to invest in.
     * @param _strategyIndex Index of the strategy to remove
     **/
    function removeStrategy(uint256 _strategyIndex) external onlyOwner {
        address strategy = strategies[_strategyIndex];
        strategies[_strategyIndex] = strategies[
            strategies.length.sub(
                1,
                "StrategyRegistry::removeStrategy - No strategies exist"
            )
        ];
        strategies.pop();

        emit StrategyRemoved(strategy);
    }

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
    ) external onlyOwner {
        require(
            strategies[_strategyIndex] == _oldStrategy,
            "StrategyRegistry::updateStrategy - index to update and strategy address don't match"
        );
        strategies[_strategyIndex] = _newStrategy;
    }
}
