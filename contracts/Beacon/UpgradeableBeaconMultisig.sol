// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/UpgradeableBeacon.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @dev This contract is used in conjunction with one or more instances of {BeaconProxy} to determine their
 * implementation contract, which is where they will delegate all function calls.
 *
 * An owner is able to change the implementation the beacon points to, thus upgrading the proxies that use this beacon.
 */
contract UpgradeableBeaconMultisig is IBeacon, Ownable {
    event SignerChangeRequested(address indexed currentSigner, address indexed newSigner);
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);
    event ImplChangeRequested(address indexed owner, address indexed newImpl);
    event Confirmation(address indexed sender, address indexed newImpl);

    uint constant public MAX_OWNER_COUNT = 10;
    mapping(address => bool) public isSigner;
    mapping(address => address) public signerChangeRequests;
    mapping(address => mapping(address => bool)) public signerChangeConfirmations;
    mapping(address => mapping(address => bool)) public confirmations;
    address[] public signers;

    address private _implementation;
    address public pendingNewImpl;

    uint public required;

    /**
     * @dev Emitted when the implementation returned by the beacon is changed.
     */
    event Upgraded(address indexed implementation);

    modifier signerExists(address signer) {
        require(isSigner[signer], "Signer does not exist");
        _;
    }

    modifier notConfirmed(address newImpl, address signer) {
        require(!confirmations[newImpl][signer], "New implemention already confirmed");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "Address cannot be null");
        _;
    }
    
    modifier validRequirement(uint _signerCount, uint _required) {
        require(_signerCount <= MAX_OWNER_COUNT && _required <= _signerCount && _required != 0 && _signerCount != 0, "Invalid requirement");
        _;
    }
    
    /**
     * @dev Sets the address of the initial implementation, and the deployer account as the owner who can upgrade the
     * beacon.
     */
    constructor(
        address implementation_, 
        address[] memory _signers, 
        uint _required
    ) validRequirement(_signers.length, _required) {
        _setImplementation(implementation_);

        for (uint i = 0; i < _signers.length; ) {
            require(!isSigner[_signers[i]] && _signers[i] != address(0) /* && _signers[i] != _msgSender()*/, "Invalid signer");
            isSigner[_signers[i]] = true;

            unchecked {
                i++;
            }
        }
        signers = _signers;
        required = _required;
    }

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view virtual override returns (address) {
        return _implementation;
    }

    function transferOwnership(address newOwner) public override virtual onlyOwner {
        // require(!isSigner[newOwner], "Ownable: new owner cannot be signer.");
        super.transferOwnership(newOwner);
    }
    function requestSignerChange(address _oldSigner, address _newSigner) external onlyOwner {
        require(isSigner[_oldSigner], "Old signer does not exist.");
        require(!isSigner[_newSigner], "New signer is already a signer.");
        require(_newSigner != owner(), "Onwer cannot be a signer.");
        
        // Clear the signerChangeConfirmations for _newSigner if a change is "in-progress"
        if (signerChangeRequests[_oldSigner] != address(0)) {
            clearSignerChangeConfirmations(signerChangeRequests[_oldSigner]);
        }

        signerChangeRequests[_oldSigner] = _newSigner;
        emit SignerChangeRequested(_oldSigner, _newSigner);
    }

    function confirmSignerChange(address _oldSigner, address _newSigner) external signerExists(_msgSender()) {
        require(!signerChangeConfirmations[_newSigner][_msgSender()], "You already confirmed.");
        require(signerChangeRequests[_oldSigner] == _newSigner, "New signer address invalid.");
        require(_newSigner != address(0), "No pending signer update request.");
        require(_newSigner != owner(), "Onwer cannot be a signer.");
        require(!isSigner[_newSigner], "New signer is already a signer.");

        // Confirm the update by the current signer
        signerChangeConfirmations[_newSigner][_msgSender()] = true;
        
        if (isSignerChangeConfirmed(_newSigner)) {
            // Clear the signerChangeConfirmations for _newSigner
            clearSignerChangeConfirmations(_newSigner);

            signerChangeRequests[_oldSigner] = address(0);
            removeSigner(_oldSigner);
            isSigner[_newSigner] = true;
            signers.push(_newSigner);
            emit SignerUpdated(_oldSigner, _newSigner);
        }
    }
    
    function requestImplChange(address newImpl) external onlyOwner {
        if (pendingNewImpl != address(0))
            clearImplChangeConfirmations(pendingNewImpl);
        pendingNewImpl = newImpl;
        emit ImplChangeRequested(_msgSender(), newImpl);
    }

    function confirmImplChange(address newImpl) public signerExists(_msgSender()) notConfirmed(newImpl, _msgSender()) {
        require(pendingNewImpl == newImpl, "Invalid new implementation address");
        confirmations[newImpl][_msgSender()] = true;
        emit Confirmation(_msgSender(), newImpl);
        if (isImplChangeConfirmed(newImpl)) {
            // Clear the signerChangeConfirmations for _newSigner
            clearImplChangeConfirmations(newImpl);
            pendingNewImpl = address(0);
            upgradeTo(newImpl);
        }
    }
    
    /**
     * @dev Sets the implementation contract address for this beacon
     *
     * Requirements:
     *
     * - `newImplementation` must be a contract.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "UpgradeableBeacon: implementation is not a contract");
        _implementation = newImplementation;
    }

    function isSignerChangeConfirmed(address _newSigner) internal view returns (bool) {
        uint256 signerCount = signers.length;
        uint256 count;
        mapping(address => bool) storage confirmation = signerChangeConfirmations[_newSigner];

        for (uint i = 0; i < signerCount && count < required; ) {
            if (confirmation[signers[i]]) count ++;
            
            unchecked {
                i++;
            }
        }

        return count == required;
    }

    function isImplChangeConfirmed(address _newImpl) internal view returns (bool) {
        uint256 signerCount = signers.length;
        uint256 count;
        mapping(address => bool) storage confirmation = confirmations[_newImpl];

        for (uint i = 0; i < signerCount && count < required; ) {
            if (confirmation[signers[i]]) count ++;
            
            unchecked {
                i++;
            }
        }

        return count == required;
    }

    function removeSigner(address oldSigner) internal {
        if (!isSigner[oldSigner]) return;

        uint256 signerCount = signers.length;
        for (uint i = 0; i < signerCount; ) {
            if (signers[i] == oldSigner) {
                if (i != signerCount - 1) {
                    signers[i] = signers[signerCount - 1];
                }
                signers.pop();
                isSigner[oldSigner] = false;
                break;
            }

            unchecked {
                i++;
            }
        }
    }

    function clearSignerChangeConfirmations(address _newSigner) internal {
        uint256 signerCount = signers.length;

        mapping(address => bool) storage confirmation = signerChangeConfirmations[_newSigner];

        for (uint i = 0; i < signerCount; ) {
            confirmation[signers[i]] = false;

            unchecked {
                i++;
            }
        }
    }

    function clearImplChangeConfirmations(address newImpl) internal {
        uint256 signerCount = signers.length;

        mapping(address => bool) storage confirmation = confirmations[newImpl];

        for (uint i = 0; i < signerCount; ) {
            confirmation[signers[i]] = false;

            unchecked {
                i++;
            }
        }
    }

    function upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

}
