const hre = require("hardhat");



async function main() {
  const impl = await hre.ethers.deployContract('MultiSigWalletTest');
  await impl.deployed();
  console.log("multisig implementation deployed to:", impl.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
