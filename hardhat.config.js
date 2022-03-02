require("@nomiclabs/hardhat-etherscan");
require('@nomiclabs/hardhat-waffle');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');

require('dotenv').config();


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.3",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },

  networks: {
    rinkeby: {
      url: 'https://eth-rinkeby.alchemyapi.io/v2/mEvGbbVlpRPPz7I9rUVb6BYGQchgfwau',
      accounts: [process.env.PK]
    },
    fuji: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      gasPrice: 225000000000,
      chainId: 43113,
      accounts: [process.env.PK]
    },
    avalanche: {
      url: 'https://speedy-nodes-nyc.moralis.io/e33bb9e9f973ece33adc88f0/avalanche/mainnet',
      gasPrice: 225000000000,
      chainId: 43114,
      accounts: [process.env.PK]
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "BFI32F2MWN6HHEPM9TF6J791HZAQW7NJVX",
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: ["polygod.sol"],
  },
  mocha: {
    timeout: 40000
  }
};
