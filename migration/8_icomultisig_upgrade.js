const hre = require("hardhat");



async function main() {
  const Ico = await hre.ethers.getContractFactory("ICOMultisig");
  const ico = await upgrades.upgradeProxy('0xB5222767a8eA9465F7B7174B3C5bD6AccF2495d5', Ico);
  console.log("ico multisig implementation deployed to:", ico.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
