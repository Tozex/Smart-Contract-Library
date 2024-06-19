require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@openzeppelin/hardhat-upgrades");
require('@nomiclabs/hardhat-truffle5');
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
      chainId: 11155111,
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
    mainnet: {
      url: process.env.MAINNET_URL || "",
      accounts:
        process.env.MNEMONIC !== undefined ? [process.env.MNEMONIC] : [],
      timeout: 200000,
      allowUnlimitedContractSize: true,
    },
    bscmainnet: {
      url: process.env.BSC_MAINNET_URL || "",
      accounts:
        process.env.MNEMONIC !== undefined ? [process.env.MNEMONIC] : [],
      timeout: 200000,
      allowUnlimitedContractSize: true,
      gasPrice: 8000000000
    },
    avalanche: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      accounts:
        process.env.MNEMONIC !== undefined ? [process.env.MNEMONIC] : [],
      timeout: 200000,
      allowUnlimitedContractSize: true,
    },
    polygonzkevm: {
      url: 'https://zkevm-rpc.com',
      accounts:
        process.env.MNEMONIC !== undefined ? [process.env.MNEMONIC] : [],
      timeout: 200000,
      allowUnlimitedContractSize: true,
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY,
    }
  },
};
