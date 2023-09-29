require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@openzeppelin/hardhat-upgrades");
require('dotenv').config()

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version:"0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
      },
    }
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_INFURA_SERVER || "",
      accounts:
        process.env.MNEMONIC !== undefined ? [process.env.MNEMONIC] : [],
    },
    bsctestnet: {
      url: process.env.BSC_TESTNET_URL || "",
      accounts:
        process.env.MNEMONIC !== undefined ? [process.env.MNEMONIC] : [],
        timeout: 20000,
      allowUnlimitedContractSize: true,
      gas: 500000000, //units of gas you are willing to pay, aka gas limit
      gasPrice: 10000000000
    },
  },
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },
};
