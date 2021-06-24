// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IPriceOracle.sol";

contract PriceOracle is Initializable, OwnableUpgradeable, IPriceOracle {
    AggregatorV3Interface internal priceFeed;
    struct PriceData {
        address oracle;
        uint256 decimals;
    }
    mapping(bytes32 => PriceData) feedAddresses;

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
        PriceData memory _feedData =
            feedAddresses[keccak256(abi.encodePacked(num, den))];
        require(
            _feedData.oracle != address(0),
            "PriceOracle::getLatestPrice - Price Feed doesn't exist"
        );
        int256 price;
        (, price, , , ) = AggregatorV3Interface(_feedData.oracle)
            .latestRoundData();
        return (uint256(price), _feedData.decimals);
    }

    function doesFeedExist(address btoken, address ctoken)
        external
        view
        override
        returns (bool)
    {
        return (feedAddresses[keccak256(abi.encodePacked(btoken, ctoken))]
            .oracle !=
            address(0) &&
            feedAddresses[keccak256(abi.encodePacked(ctoken, btoken))].oracle !=
            address(0));
    }

    function setfeedAddress(
        address btoken,
        address ctoken,
        address priceOracle1,
        address priceOracle2
    ) external onlyOwner {
        uint256 priceOracle1Decimals =
            AggregatorV3Interface(priceOracle1).decimals();
        feedAddresses[keccak256(abi.encodePacked(btoken, ctoken))] = PriceData(
            priceOracle1,
            priceOracle1Decimals
        );
        uint256 priceOracle2Decimals =
            AggregatorV3Interface(priceOracle2).decimals();
        feedAddresses[keccak256(abi.encodePacked(ctoken, btoken))] = PriceData(
            priceOracle2,
            priceOracle2Decimals
        );
    }
}
