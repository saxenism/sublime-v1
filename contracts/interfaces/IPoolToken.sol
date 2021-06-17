// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolToken is IERC20 {
    function burn(address user, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function pause() external;
}
