// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

contract Verification is Initializable, OwnableUpgradeable {
    mapping(address => bytes32) public registeredUsers;

    event UserRegistered(address user, bytes32 offChainDetails);
    event UserDetailsUpdated(address user, bytes32 offChainDetails);
    event UserUnregistered(address user);

    event CollateralAdded(bytes32 poolHash, uint256 amount);
    event AmountBorrowed(bytes32 poolHash, address user, uint256 amount, uint256 time);

    event CollateralWithdrawn(bytes32 poolHash, address user, uint256 amount);

    modifier ifUserRegistered(address _user) {
        require(registeredUsers[_user] != bytes32(0), 'Verification: User must be registered');
        _;
    }

    function initialize(address _admin) public initializer {
        super.__Ownable_init();
        super.transferOwnership(_admin);
    }

    /**
     * @dev Used to add users in the protocol. Intitially it will
            be manage by the admin but down the line it will be governanace based function.
     * @param _user Address that need to be added into the allowed list of users.
     * @param _offChainDetails It can be a hash of any Identity details provided by an entity during on boarding.
            ex- twitter handle etc.
    */
    function registerUser(address _user, bytes32 _offChainDetails) external onlyOwner {
        require(registeredUsers[_user] == bytes32(0), 'Verification: User already registered');
        require(_user != address(0), 'Verification: Invalid entity address');
        require(_offChainDetails != bytes32(0), 'Verification: Offchain details should not be empty');
        registeredUsers[_user] = _offChainDetails;
        emit UserRegistered(_user, _offChainDetails);
    }

    function updateUserDetails(address _user, bytes32 _offChainDetails) external onlyOwner ifUserRegistered(_user) {
        require(_offChainDetails != bytes32(0), 'Verification: Offchain details should not be empty');

        registeredUsers[_user] = _offChainDetails;
        emit UserDetailsUpdated(_user, _offChainDetails);
    }

    function unregisterUser(address _user) external onlyOwner ifUserRegistered(_user) {
        delete registeredUsers[_user];
        emit UserUnregistered(_user);
    }

    function isUser(address _user) public view returns (bool) {
        return (registeredUsers[_user] != bytes32(0));
    }
}
