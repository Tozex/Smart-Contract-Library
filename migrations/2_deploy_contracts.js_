const dotenv = require('dotenv');
const Web3 = require('web3');
var MintableToken = artifacts.require('./Token/ERC20/MintableToken.sol');
var BRO = artifacts.require('./BRO/BRO.sol');

dotenv.config();

module.exports = function(deployer, network) {
  var gasOptions = {
    gasPrice: 10000000000
  };

    // deploy all main contracts
  var name = 'Tozex Token';
  var symbol = 'TOZ';
  var decimals = 18;
  var version = '1.0.0';

  var tozTokenInstance;

  deployer.deploy(MintableToken, name, symbol, decimals, gasOptions)
    .then(tokenInstance => {
      console.log(`[TozexToken] contract deployed`)
      tozTokenInstance = tokenInstance;
      return deployer.deploy(tokenInstance.address, "0xD8c47d7f9691C83E1A92B813c49A2471695Ad1eb", 30, tokenInstance.address, tokenInstance.address);
    })
    .catch(err => {
      console.log(`Error deploying contracts; \n ${err}`);
    })
};
