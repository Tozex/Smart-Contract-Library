// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "../Beacon/UpgradeableBeaconMultisig.sol";
import "../MultiSigWallet/MultiSigWalletAPI.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

 contract VaultProxyBeaconFactory is OwnableUpgradeable{
    address public beacon;

    address[] public beacons;
    
    event VaultCreated(address proxyAddress, address owner, address[] signers, uint required, string indentifier);

    constructor(address implementation_, address[] memory signers, uint required, address _owner, string memory _indentifier) {
        _transferOwnership(_owner);
        UpgradeableBeaconMultisig _beacon = new UpgradeableBeaconMultisig(
            implementation_,
            signers,
            required,
            _indentifier
        );
        _beacon.transferOwnership(_owner);
        beacon = address(_beacon);
    }

    function create(
        address[] calldata signers,
        uint required,
        string calldata indentifier
    ) external returns (address) {
        address proxyAddress = address(new BeaconProxy(beacon, abi.encodeWithSelector(MultiSigWalletAPI(payable(address(0))).initialize.selector, signers, required, owner(), indentifier)));
        beacons.push(proxyAddress);
        emit VaultCreated(proxyAddress, owner(), signers, required, indentifier);
        return proxyAddress;
    }
 }