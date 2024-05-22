const hre = require("hardhat");



async function main() {

  // deploy implementation
  const impl = await hre.ethers.deployContract('MultiSigWalletAPI', ["0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF"]);
  await impl.deployed();
  console.log("Multisig implementation deployed to:", impl.address);

  // deploy beacon factory
  const beaconFactory = await hre.ethers.deployContract('VaultProxyBeaconFactory', [impl.address, ["0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1"], 2, "0x5b88B0a3860a4FB8ebfe74E0aefF83167829506a", "0"]);
  await beaconFactory.deployed();
  console.log("Beacon factory deployed to:", beaconFactory.address);

  // create new vault
  // const result = await beaconFactory.create(["0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF", "0xd1A6A0F87Ec5845842B42e9845Cea2f054E9a719"], 2, 0);
  // let receipt = await result.wait();
  // const event = receipt.events?.filter((x) => {return x.event == "VaultCreated"})[0];
  // console.log("New vault deployed to:", event.args[0]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
