// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "../Beacon/UpgradeableBeaconMultisig.sol";
import "../MultiSigWallet/MultiSigWalletAPI.sol";
 contract VaultProxyBeaconFactory {
    address public beacon;

    address[] public beacons;
    
    event VaultCreated(address proxyAddress, uint timestamp);

    constructor(address implementation_, address[] memory signers, uint required, address owner) {
        UpgradeableBeaconMultisig _beacon = new UpgradeableBeaconMultisig(
            implementation_,
            signers,
            required
        );
        _beacon.transferOwnership(owner);
        beacon = address(_beacon);
    }

    function create(
        address[] memory signers,
        uint required
    ) external returns (address) {
        address proxyAddress = address(new BeaconProxy(beacon, abi.encodeWithSelector(MultiSigWalletAPI(payable(address(0))).initialize.selector, signers, required)));
        beacons.push(proxyAddress);
        emit VaultCreated(proxyAddress, block.timestamp);
        return proxyAddress;
    }
 }