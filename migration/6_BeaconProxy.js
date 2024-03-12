const hre = require("hardhat");



async function main() {
  const MultiSigWallet = await hre.ethers.getContractFactory("MultiSigWalletAPI");

  const beconProxy = await hre.upgrades.deployBeaconProxy("0xD1A6e2339726c76780c0F523136c65c94C16279C", MultiSigWallet, [["0xF79244be8F46E4687A7150a76bFD821e775f26bB", "0xe249BEc3a1FDCea562Abf1479C641106DB8421C3","0x443112E22cc72020C29e8240174115bD0bdB0C4E", "0xB2e0adeB86467107659B7E56480Afe72C8F3AD55"], 2]);

  await beconProxy.deployed();

  console.log("BeconProxy deployed to:", beconProxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
