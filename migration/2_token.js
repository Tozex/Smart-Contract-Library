const hre = require("hardhat");



async function main() {
  const impl = await hre.ethers.deployContract('MockToken', ["DPS", "DPS"]);
  await impl.deployed();
  console.log("token deployed to:", impl.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
