// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IPriceOracle.sol";

contract PriceOracle is OwnableUpgradeable, IPriceOracle {
    AggregatorV3Interface internal priceFeed;
    mapping(bytes32 => address) feedAddresses;

    constructor(address _admin) {
        OwnableUpgradeable.__Ownable_init();
        OwnableUpgradeable.transferOwnership(_admin);
    }
 
    function getLatestPrice(address num, address den)
        public
        override
        view
        returns (uint256)
    {
        address _feedAddress = feedAddresses[keccak256(abi.encodePacked(num, den))];
        require(_feedAddress != address(0), "PriceOracle::getLatestPrice - Price Feed doesn't exist");
        int256 price;
        (, price, , , ) = AggregatorV3Interface(_feedAddress).latestRoundData();
        return uint256(price);
    }

    function doesFeedExist(address btoken, address ctoken) external view override returns(bool) {
        return (
            feedAddresses[keccak256(abi.encodePacked(btoken, ctoken))] != address(0) 
            && feedAddresses[keccak256(abi.encodePacked(ctoken, btoken))] != address(0)
        );
    }

    function setfeedAddress(address btoken, address ctoken, address priceOracle1, address priceOracle2) external onlyOwner {
        feedAddresses[
            keccak256(abi.encodePacked(btoken, ctoken))
        ] =  priceOracle1;
        feedAddresses[
            keccak256(abi.encodePacked(ctoken, btoken))
        ] = priceOracle2;
    }
}
