const hre = require("hardhat");



async function main() {
  const MultiSigWallet = await hre.ethers.getContractFactory("MultiSigWallet");

  // const impl = await hre.ethers.deployContract('MultiSigWallet');
  // await impl.deployed();
  // console.log("multisig implementation deployed to:", impl.address);

  const beacon = await hre.ethers.deployContract('UpgradeableBeaconMultisig', ['0xF4fA1449992b28B6a005f158C7842529739d612a', ["0xB2e0adeB86467107659B7E56480Afe72C8F3AD55", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1","0x9eb3F4241C3FAb15570b11b0E7EAce432f0e19c4"], 2]);
  await beacon.deployed();
  console.log("Becon deployed to:", beacon.address);

  const beconProxy = await hre.upgrades.deployBeaconProxy(beacon.address, MultiSigWallet, [["0xB2e0adeB86467107659B7E56480Afe72C8F3AD55", "0xEBE8Fc0E1B84714Cc85C72C3E6EBb037247AEAA1", "0xB5222767a8eA9465F7B7174B3C5bD6AccF2495d5"], 3]);

  await beconProxy.deployed();

  console.log("BeconProxy deployed to:", beconProxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
