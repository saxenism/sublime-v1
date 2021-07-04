// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IPriceOracle.sol";

contract PriceOracle is Initializable, OwnableUpgradeable, IPriceOracle {
    using SafeMath for uint256;

    AggregatorV3Interface internal priceFeed;
    struct PriceData {
        address oracle;
        uint256 decimals;
    }
    mapping(address => PriceData) feedAddresses;

    function initialize(address _admin) public initializer {
        OwnableUpgradeable.__Ownable_init();
        OwnableUpgradeable.transferOwnership(_admin);
    }

    function getLatestPrice(address num, address den)
        public
        view
        override
        returns (uint256, uint256)
    {
        PriceData memory _feedData1 = feedAddresses[num];
        PriceData memory _feedData2 = feedAddresses[den];
        require(
            _feedData1.oracle != address(0) && _feedData2.oracle != address(0),
            "PriceOracle::getLatestPrice - Price Feed doesn't exist"
        );
        int256 price1;
        int256 price2;
        (, price1, , , ) = AggregatorV3Interface(_feedData1.oracle)
            .latestRoundData();
        (, price2, , , ) = AggregatorV3Interface(_feedData2.oracle)
            .latestRoundData();

        uint256 price =
            uint256(price1)
                .mul(10**_feedData2.decimals)
                .mul(10**30)
                .div(uint256(price2))
                .div(10**_feedData1.decimals);
        return (price, 30);
    }

    function doesFeedExist(address[] calldata tokens)
        external
        view
        override
        returns (bool)
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (feedAddresses[tokens[i]].oracle == address(0)) {
                return false;
            }
        }
        return true;
    }

    function setfeedAddress(address token, address priceOracle)
        external
        onlyOwner
    {
        uint256 priceOracleDecimals =
            AggregatorV3Interface(priceOracle).decimals();
        feedAddresses[token] = PriceData(priceOracle, priceOracleDecimals);
    }
}
