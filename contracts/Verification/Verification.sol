// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Verification is Initializable, OwnableUpgradeable {

    mapping(address => bytes32) public verifiedUsers;


    event UserVerified(address user, bytes32 offChainDetails);
    event UserDetailsUpdated(address user, bytes32 offChainDetails);
    event UserUnverified(address user);

    event CollateralAdded(bytes32 poolHash, uint256 amount);
    event AmountBorrowed(
        bytes32 poolHash,
        address user,
        uint256 amount,
        uint256 time
    );

    event CollateralWithdrawn(
        bytes32 poolHash,
        address user,
        uint256 amount
    );

    modifier ifUserVerified(address _user) {
        require(
            verifiedUsers[_user] != bytes32(0),
            "Verification: User must be verified"
        );
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
    function verifyUser(address _user, bytes32 _offChainDetails)
        external
        onlyOwner
    {
        require(verifiedUsers[_user] == bytes32(0), "Verification: User already verified");
        require(_user != address(0), "Verification: Invalid entity address");
        require(
            _offChainDetails != bytes32(0),
            "Verification: Offchain details should not be empty"
        );
        verifedUsers[_user] = _offChainDetails;
        emit UserVerified(_user, _offChainDetails);
    }

    function updateUserDetails(address _user, bytes32 _offChainDetails)
        external
        onlyOwner
        ifUserVerified(_user)
    {
        require(
            _offChainDetails != bytes32(0),
            "Verification: Offchain details should not be empty"
        );

        verifiedUsers[_user] = _offChainDetails;
        emit UserDetailsUpdated(_user, _offChainDetails);
    }

    function unverifyUser(address _user) 
        external 
        onlyOwner
        ifUserverified(_user)
    {
        delete verifiedUsers[_user];
        emit UserUnverified(_user);
    }

    function isUser(address _user) public view returns(bool) {
        return (verifiedUsers[_user] != bytes32(0));
    }
}
