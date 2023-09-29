const hre = require("hardhat");


async function main() {
  const MultiSigWallet = await hre.ethers.getContractFactory("MultiSigWallet");
  console.log(hre.upgrades)
  const multisig = await hre.upgrades.deployProxy(MultiSigWallet, [["0xB2e0adeB86467107659B7E56480Afe72C8F3AD55", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1","0x4fd2f6C62c532b35C75dE2493D17eb4FcDA38479"], 2]);

  await multisig.deployed();

  console.log("multisig deployed to:", multisig.address);
  const multisigImpl = await hre.upgrades.erc1967.getImplementationAddress(multisig.address);
  console.log("multisig implementaion deployed to:", multisigImpl);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
