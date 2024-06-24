const hre = require("hardhat");



async function main() {

  // deploy implementation
  const forwarderAddress = "0xbdeA59c8801658561a16fF58D68FC2b198DE4E93";
  const owner = "0xC88522F40CCdfCe593E027F230c57a5F24211344";
  const impl = await hre.ethers.deployContract('MultiSigWalletAPI', [forwarderAddress]);
  await impl.deployed();
  console.log("Multisig implementation deployed to:", impl.address);

  // deploy beacon factory
  const beaconFactory = await hre.ethers.deployContract('VaultProxyBeaconFactory', [forwarderAddress, impl.address, ["0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1"], 2, owner]);
  await beaconFactory.deployed();
  console.log("Beacon factory deployed to:", beaconFactory.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
