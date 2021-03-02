// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Borrower is Initializable, OwnableUpgradeable {
    // using SafeMath for uint256;

    mapping(address => bytes32) public registeredBorrowers;

    event BorrowerRegistered(address borrower, bytes32 offChainDetails);
    event BorrowerDetailsUpdated(address borrower, bytes32 offChainDetails);
    event BorrowerUnregistered(address borrower);

    event CollateralAdded(bytes32 poolHash, uint256 amount);
    event AmountBorrowed(
        bytes32 poolHash,
        address borrower,
        uint256 amount,
        uint256 time
    );

    event CollateralWithdrawn(
        bytes32 poolHash,
        address borrower,
        uint256 amount
    );

    modifier ifBorrowerRegistered(address borrower) {
        require(
            registeredBorrowers[borrower] != bytes32(0),
            "Borrower: Borrower must be registered"
        );
        _;
    }

    function initialize(address _admin) public initializer {
        
    }

    /**
     * @dev Used to add borrowers in the protocol. Intitially it will
            be manage by the admin but down the line it will be governanace based function.
     * @param _borrower Address that need to be added into the allowed list of borrowers.
     * @param _offChainDetails It can be a hash of any Identity details provided by an entity during on boarding.
            ex- twitter handle etc.
    */
    function registerBorrower(address _borrower, bytes32 _offChainDetails)
        external
        onlyOwner
    {
        
    }

    function updateBorrowerDetails(address _borrower, bytes32 _offChainDetails)
        external
        onlyOwner
        ifBorrowerRegistered(_borrower)
    {
        
    }

    function unregisterBorrower(address _borrower) 
        external 
        onlyOwner
        ifBorrowerRegistered(_borrower)
    {
        
    }

    function isBorrower(address _borrower) public view returns(bool) {
        
    }
}
