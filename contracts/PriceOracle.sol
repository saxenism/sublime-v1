// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import '@chainlink/contracts/src/v0.7/interfaces/AggregatorV3Interface.sol';
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './interfaces/IPriceOracle.sol';

contract PriceOracle is Initializable, OwnableUpgradeable, IPriceOracle {
    using SafeMath for uint256;

    uint32 uniswapPriceAveragingPeriod;
    struct PriceData {
        address oracle;
        uint256 decimals;
    }
    mapping(address => PriceData) chainlinkFeedAddresses;

    mapping(bytes32 => address) uniswapPools;

    event ChainlinkFeedUpdated(address token, address priceOracle);
    event UniswapFeedUpdated(address token1, address token2, bytes32 feedId, address pool);
    event UniswapPriceAveragingPeriodUpdated(uint32 uniswapPriceAveragingPeriod);

    function initialize(address _admin) public initializer {
        OwnableUpgradeable.__Ownable_init();
        OwnableUpgradeable.transferOwnership(_admin);
    }

    function getChainlinkLatestPrice(address num, address den) public view returns (uint256, uint256) {
        PriceData memory _feedData1 = chainlinkFeedAddresses[num];
        PriceData memory _feedData2 = chainlinkFeedAddresses[den];
        if(_feedData1.oracle == address(0) || _feedData2.oracle == address(0)) {
            return (0, 0);
        }
        int256 price1;
        int256 price2;
        (, price1, , , ) = AggregatorV3Interface(_feedData1.oracle).latestRoundData();
        (, price2, , , ) = AggregatorV3Interface(_feedData2.oracle).latestRoundData();

        uint256 price = uint256(price1).mul(10**_feedData2.decimals).mul(10**30).div(uint256(price2)).div(10**_feedData1.decimals);
        return (price, 30);
    }

    function getUniswapLatestPrice(address num, address den) public view returns (uint256, uint256) {
        bytes32 _poolTokensId = getUniswapPoolTokenId(num, den);
        address _pool = uniswapPools[_poolTokensId];
        if(_pool == address(0)) {
            return (0, 0);
        }
        int24 _twapTick = OracleLibrary.consult(_pool, uniswapPriceAveragingPeriod);
        uint256 _numTokens = OracleLibrary.getQuoteAtTick(_twapTick, 10**30, den, num);
        return (_numTokens, 30);
    }

    function getUniswapPoolTokenId(address num, address den) internal pure returns(bytes32) {
        if(uint256(num) < uint256(den)) {
            return keccak256(abi.encodePacked(num, den));
        } else {
            return keccak256(abi.encodePacked(num, den));
        }
    }

    function getLatestPrice(address num, address den) public view override returns (uint256, uint256) {
        uint256 _price;
        uint256 _decimals;
        (_price, _decimals) = getChainlinkLatestPrice(num, den);
        if(_decimals != 0) {
            return (_price, _decimals);
        }

        (_price, _decimals) = getUniswapLatestPrice(num, den);
        if(_decimals != 0) {
            return (_price, _decimals);
        }

        revert("PriceOracle::getLatestPrice - Price Feed doesn't exist");
    }

    function doesFeedExist(address token1, address token2) external view override returns (bool) {
        if(
            chainlinkFeedAddresses[token1].oracle != address(0) &&
            chainlinkFeedAddresses[token2].oracle != address(0)
        ) {
            return true;
        }

        bytes32 _poolTokensId = getUniswapPoolTokenId(token1, token2);

        if(
            uniswapPools[_poolTokensId] != address(0)
        ) {
            return true;
        }

        return false;
    }

    function setChainlinkFeedAddress(address token, address priceOracle) external onlyOwner {
        uint256 priceOracleDecimals = AggregatorV3Interface(priceOracle).decimals();
        chainlinkFeedAddresses[token] = PriceData(priceOracle, priceOracleDecimals);
        emit ChainlinkFeedUpdated(token, priceOracle);
    }

    function setUniswapFeedAddress(address token1, address token2, address pool) external onlyOwner {
        bytes32 _poolTokensId = getUniswapPoolTokenId(token1, token2);
        uniswapPools[_poolTokensId] = pool;
        emit UniswapFeedUpdated(token1, token2, _poolTokensId, pool);
    }

    function setUniswapPriceAveragingPeriod(uint32 _uniswapPriceAveragingPeriod) external onlyOwner {
        uniswapPriceAveragingPeriod = _uniswapPriceAveragingPeriod;
        emit UniswapPriceAveragingPeriodUpdated(_uniswapPriceAveragingPeriod);
    }
}
