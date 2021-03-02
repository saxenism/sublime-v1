// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@chainlink/contracts/v0.6/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {
    AggregatorV3Interface internal priceFeed;
    mapping(bytes32 => address) feedAddresses;
    mapping(address => string) addressToString;

    constructor(address btoken, address ctoken, address priceOracle1, address priceOracle2) {
        addressToString[btoken] = "BTOKEN";
        addressToString[ctoken] = "CTOKEN";
        setfeedAddress(priceOracle1, priceOracle2);
    }
 
    function getLatestPrice(address num, address den)
        public
        view
        returns (int256 price)
    {
        // 0x9326BFA02ADD2366b30bacB125260Af641031331
        (, price, , , ) = AggregatorV3Interface(
            feedAddresses[getHash(num, den)]
        )
            .latestRoundData();
    }

    function getHash(address num, address den) internal view returns (bytes32) {
        return (
            bytes32(
                keccak256(
                    abi.encodePacked(addressToString[num], addressToString[den])
                )
            )
        );
    }

    function setfeedAddress(address priceOracle1, address priceOracle2) internal {
        feedAddresses[
            keccak256(abi.encodePacked("BTOKEN", "CTOKEN"))
        ] =  priceOracle1;
        feedAddresses[
            keccak256(abi.encodePacked("CTOKEN", "BTOKEN"))
        ] = priceOracle2;
    }
}
