// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "../Beacon/UpgradeableBeaconMultisig.sol";
import "../MultiSigWallet/MultiSigWalletAPI.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
contract VaultProxyBeaconFactory is
    OwnableUpgradeable,
    ERC2771ContextUpgradeable
{
    address public beacon;
    address[] public beacons;

    event VaultCreated(
        address proxyAddress,
        address owner,
        address creator,
        address[] signers,
        uint required,
        string indentifier
    );
    event FactoryBeaconOwnerChanged(
        address indexed oldOwner,
        address indexed newOwner
    );

    constructor(
        address trustedForwarder,
        address implementation_,
        address[] memory signers,
        uint required,
        address _owner
    ) ERC2771ContextUpgradeable(trustedForwarder) initializer {
        _transferOwnership(_owner);
        UpgradeableBeaconMultisig _beacon = new UpgradeableBeaconMultisig(
            implementation_,
            signers,
            required
        );
        _beacon.transferOwnership(_owner);
        beacon = address(_beacon);
    }

    function create(
        address[] calldata signers,
        uint required,
        string calldata indentifier
    ) external returns (address) {
        address proxyAddress = address(
            new BeaconProxy(
                beacon,
                abi.encodeWithSelector(
                    MultiSigWalletAPI(payable(address(0))).initialize.selector,
                    signers,
                    required,
                    owner(),
                    indentifier
                )
            )
        );
        beacons.push(proxyAddress);
        emit VaultCreated(
            proxyAddress,
            owner(),
            _msgSender(),
            signers,
            required,
            indentifier
        );
        return proxyAddress;
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
    function _contextSuffixLength()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return 20;
    }
}
