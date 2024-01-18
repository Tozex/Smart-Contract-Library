const hre = require("hardhat");



async function main() {
  const MultiSigWallet = await hre.ethers.getContractFactory("MultiSigWallet");

  const beconProxy = await hre.upgrades.deployBeaconProxy("0x17DBEfC6F36E47BA8d478122B953e8A50bFB4908", MultiSigWallet, [["0x91E9dD0FA1ef0538aB3b291b8F631188d90021fe", "0x218C65Ba7A541EfCBBfE033F606E3896e6E83146","0x61fe7436Eb3C00dFCA11dd266052AABA3E02875b", "0x2B2f57bEc1467E4bf879E231Bb60F88c168caA35"], 3]);

  await beconProxy.deployed();

  console.log("BeconProxy deployed to:", beconProxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
