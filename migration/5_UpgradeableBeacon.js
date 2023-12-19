const hre = require("hardhat");



async function main() {
  const MultiSigWallet = await hre.ethers.getContractFactory("MultiSigWallet");

  // const impl = await hre.ethers.deployContract('MultiSigWallet');
  // await impl.deployed();
  // console.log("multisig implementation deployed to:", impl.address);

  const beacon = await hre.ethers.deployContract('UpgradeableBeaconMultisig', ['0x5323b5c74a57c7772729d47636d114a1eef68262', ["0xB2e0adeB86467107659B7E56480Afe72C8F3AD55", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1","0x9eb3F4241C3FAb15570b11b0E7EAce432f0e19c4"], 2]);
  await beacon.deployed();
  console.log("Becon deployed to:", beacon.address);

  const beconProxy = await hre.upgrades.deployBeaconProxy(beacon.address, MultiSigWallet, [["0xF79244be8F46E4687A7150a76bFD821e775f26bB", "0xe249BEc3a1FDCea562Abf1479C641106DB8421C3","0x443112E22cc72020C29e8240174115bD0bdB0C4E", "0x93BF5828f7AFff6139E704ba58fF87128E26C1e6"], 2]);

  await beconProxy.deployed();

  console.log("BeconProxy deployed to:", beconProxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
