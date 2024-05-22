const hre = require("hardhat");



async function main() {

  const factoryAddress = "0x8DF406614af62e9b65C05f3E3246cC9b4Dbf2879";
  const beacon = await hre.ethers.getContractAt("VaultProxyBeaconFactory", factoryAddress);
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
