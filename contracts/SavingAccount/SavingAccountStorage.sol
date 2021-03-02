// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
// import "./PoolLenderGetterSetter.sol";
// import "../interfaces/IPool.sol";
// import "../interfaces/IRepayment.sol";

contract SavingAccountStorage{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;    

    
    // address internal invest;
    // assuming number of days in year is 356 more discussion is needed for this
    uint public constant yearSeconds = 365 days;
    // TODO: this can probably be removed
    mapping(address => mapping(address => uint256)) public savingAccountInfo;
    mapping(address => mapping(address => mapping(address => uint))) public userLockedBalance;
    // TODO : Track strategies per user and limit no of strategies to 5
    address[] strategies;
    uint256 maxStrategies;
}
