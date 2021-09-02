// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import '@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '../interfaces/IPool.sol';

/**
 * @title Pool Token contract with Methods related to Pool Token
 * @notice Implements the functions related to Pool Token
 * @author Sublime
 */
contract PoolToken is Initializable, ERC20PresetMinterPauserUpgradeable {
    using SafeMath for uint256;

    /**
    * @notice assigning hash of "BURNER_ROLE" as a constant
    */
    bytes32 public constant BURNER_ROLE = keccak256('BURNER_ROLE');

    /**
    * @notice address of the open borrow pool
    */
    address public pool;

    /**
     * @notice initializing the pool and assigning minter, pauser and burner roles
     * @param name name of the pool token
     * @param symbol symbol of the pool token
     * @param _pool address of the open borrow pool
     */
    function initialize(
        string memory name,
        string memory symbol,
        address _pool
    ) public initializer {
        ERC20PresetMinterPauserUpgradeable.__ERC20PresetMinterPauser_init(name, symbol);
        _setupRole(MINTER_ROLE, _pool);
        _setupRole(PAUSER_ROLE, _pool);
        _setupRole(BURNER_ROLE, _pool);
        pool = _pool;
    }

    /**
     * @notice allows the user to burn said amount of tokens
     * @param user address of the user requesting to burn tokens
     * @param amount amount of tokens to burn
     */
    function burn(address user, uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender));
        _burn(user, amount);
    }

    /**
     * @notice internal function to ensure safe token transfer (valid to address and unpaused tokens)
     * @param from address of the sender
     * @param to address of the receiver
     * @param amount amount of tokens to transfer
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override{
        if (to != address(0)) {
            // super._beforeTokenTransfer(from, to, amount);  //To silence the warnings
            require(!paused(), 'ERC20Pausable: token transfer while paused');
        }
    }

    /**
     * @notice used to transfer tokens from msg.sender
     * @param _recipient address of the recipient
     * @param _amount amount of tokens to transfer
     * @return bool notifying status of token transfer
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        IPool(pool).beforeTransfer(_msgSender(), _recipient, _amount);
        _transfer(_msgSender(), _recipient, _amount);
        return true;
    }

    /**
     * @notice used to transfer tokens from a _sender
     * @param _sender address of the sender
     * @param _recipient address of the recipient
     * @param _amount amount of tokens to transfer
     * @return bool notifying status of token transfer
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        IPool(pool).beforeTransfer(_sender, _recipient, _amount);
        _transfer(_sender, _recipient, _amount);
        _approve(_sender, _msgSender(), allowance(_sender, _msgSender()).sub(_amount, 'ERC20: transfer amount exceeds allowance'));
        return true;
    }
}
