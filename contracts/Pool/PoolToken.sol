// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IPool.sol";

contract PoolToken is Initializable, ERC20PresetMinterPauserUpgradeable {
    using SafeMath for uint256;

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    address public pool;

    function initialize(
        string memory name,
        string memory symbol,
        address _pool
    ) public initializer {
        ERC20PresetMinterPauserUpgradeable.__ERC20PresetMinterPauser_init(
            name,
            symbol
        );
        _setupRole(MINTER_ROLE, _pool);
        _setupRole(PAUSER_ROLE, _pool);
        _setupRole(BURNER_ROLE, _pool);
        pool = _pool;
    }

    function burn(address user, uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender));
        _burn(user, amount);
    }

    function transfer(address _recipient, uint256 _amount)
        public
        override
        returns (bool)
    {
        IPool(pool).beforeTransfer(_msgSender(), _recipient, _amount);
        _transfer(_msgSender(), _recipient, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        IPool(pool).beforeTransfer(_sender, _recipient, _amount);
        _transfer(_sender, _recipient, _amount);
        _approve(
            _sender,
            _msgSender(),
            allowance(_sender, _msgSender()).sub(
                _amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }
}
