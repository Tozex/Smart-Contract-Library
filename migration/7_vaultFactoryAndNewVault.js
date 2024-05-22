const hre = require("hardhat");



async function main() {

  // deploy implementation
  const impl = await hre.ethers.deployContract('MultiSigWalletAPI', ["0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF"]);
  await impl.deployed();
  console.log("Multisig implementation deployed to:", impl.address);

  // deploy beacon factory
  const beacon = await hre.ethers.deployContract('VaultProxyBeaconFactory', [impl.address, ["0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1"], 2, "0xb2972e9c2524c0aEb31A18C277Ac88fDA074FC2D"]);
  await beacon.deployed();
  console.log("Beacon factory deployed to:", beacon.address);

  // create new vault
  const result = await beacon.create(["0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1"], 2);
  let receipt = await result.wait();
  const event = receipt.events?.filter((x) => {return x.event == "VaultCreated"})[0];
  console.log("New vault deployed to:", event.args[0]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
