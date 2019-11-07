// Allows us to use ES6 in migrations and tests.
require('babel-register')
require('babel-polyfill')
var PrivateKeyProvider = require("truffle-privatekey-provider");

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new PrivateKeyProvider('886e44e4e1d22cc0dcd596f59d64cd8744b46a684a2d17c0cbac404641b88537', "http://35.247.55.112:8545");
      },
      gas: 3000000,
      gasPrice: 20000000000,
      network_id: 3 // Match any network id
    }
  },
  compilers: {
    solc: {
      version: "0.4.24",
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
