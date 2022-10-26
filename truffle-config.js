// Allows us to use ES6 in migrations and tests.
require("babel-register");
require("babel-polyfill");
const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      gas: 6000000,
      network_id: "*", // Match any network id
    },
    goerli: {
      provider: () => {
        return new HDWalletProvider(
          process.env.MNEMONIC,
          "https://goerli.infura.io/v3/" + process.env.INFURA_API_KEY
        );
      },
      network_id: "5",
      gas: 10_000_000,
      gasPrice: 40_000_000,
    },
  },
  compilers: {
    solc: {
      version: "0.4.24",
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  mocha: {
    enableTimeouts: false,
  },
};
