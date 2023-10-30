const hre = require("hardhat");


async function main() {
  const MultiSigWallet = await hre.ethers.getContractFactory("MultiSigWallet");
  console.log(hre.upgrades)
  const multisig = await hre.upgrades.deployProxy(MultiSigWallet, [["0xF79244be8F46E4687A7150a76bFD821e775f26bB", "0xe249BEc3a1FDCea562Abf1479C641106DB8421C3","0x443112E22cc72020C29e8240174115bD0bdB0C4E", "0x93BF5828f7AFff6139E704ba58fF87128E26C1e6"], 2]);

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
