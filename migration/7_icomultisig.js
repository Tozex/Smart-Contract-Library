const hre = require("hardhat");



async function main() {
  
  const softCap = hre.ethers.BigNumber.from('135000000000000000000000');
  const maxCap = hre.ethers.BigNumber.from('375000000000000000000000');
  const Ico = await hre.ethers.getContractFactory("ICOMultisig");
  const ico = await hre.upgrades.deployProxy(Ico, ['0xD7a24d22Cb1E94a4cF71E2E8338849382A7877bB', '0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e', '0xf192caE2e7Cd4048Bea307368015E3647c49338e', 600, 75,  softCap, maxCap]);
  await ico.deployed();
  console.log("ico multisig implementation deployed to:", ico.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
