const hre = require("hardhat");



async function main() {

  const factoryAddress = "0x19c2BD0C321199B2bCfb2Ed4aF140A6c74A55dB8";
  const beacon = await hre.ethers.getContractAt("VaultProxyBeaconFactory", factoryAddress);
  const result = await beacon.create(["0x6F661f14143f06f0E43344975D7f8c26C7556752", "0xCA1D3D369Ac056A8857572B1437Ee2E43D6c73bF"], 2);

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
