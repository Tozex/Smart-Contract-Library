const dotenv = require('dotenv');
var Multisig = artifacts.require('MultisigWallet');

module.exports = async function (deployer, network, accounts) {
  await deploy_multisig(deployer, network, accounts);
};

async function deploy_multisig(deployer, network, accounts) {
  await deployer.deploy(Multisig,  ["0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "0xdB5FB6C5Eaae9FcA2F4d00FbdCD10169D08357a0", "0x0590f20a7F1B6799979d2D59D10242e1081D8d9c"], 3);
}

