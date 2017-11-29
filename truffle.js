// Allows us to use ES6 in migrations and tests.
require('babel-register')
require('babel-polyfill')

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      gas: 900000000,
      network_id: "*" // Match any network id
    }
  }
};
