//  .eth-txs tester
//
//  usage:
//  1) copy transactions to ./test.eth-txs
//  2) update the `const FROM` in this file to match the sender address
//  3) optionally write any addition tests to run post-txs
//  4) start a local mainnet fork with:
//     ganache-cli --fork 'https://mainnet.infura.io/v3/2599df54929b47099bda360958d75aaf' --unlock '0xsenderaddress'
//  5) truffle test ./test-extras/TestEthTxs.js

const FROM = '0xsenderaddress';
const TXS_FILE = './test.eth-txs';

const fs = require('fs');

const Azimuth = artifacts.require('Azimuth');
const Ecliptic = artifacts.require('Ecliptic');

contract('eth-txs', function() {
  let txs = [];
  let azimuth, ecliptic;

  before('setting up', async function() {
    azimuth = await Azimuth.at('0x223c067F8CF28ae173EE5CafEa60cA44C335fecB');
    ecliptic = await Ecliptic.at(await azimuth.owner())

    if (fs.existsSync(TXS_FILE)) {
      const file = fs.readFileSync(TXS_FILE);
      const lines = file.toString().split('\n');
      //  nonce, gas-price, gas, to, value, data, chain-id
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i];
        if (line === '') continue;
        const data = line.split(',');
        if (data.length !== 7) {
          console.log('weird data', data);
          continue;
        }
        txs.push({
          nonce: data[0].slice(2),
          gasPrice: data[1].slice(2),
          gas: data[2].slice(2),
          to: data[3],
          value: data[4].slice(2),
          data: data[5],
          chainId: data[6]
        });
      }
      console.log('found', txs.length, 'txs');
    } else {
      console.log('no test.eth-txs file... will do nothing!');
    }
  });

  it('can submit transactions cleanly', async function() {
    for (let i = 0; i < txs.length; i++) {
      let tx = txs[i];
      tx.from = FROM;
      const receipt = await web3.eth.sendTransaction(tx);
      assert.isTrue(receipt.status);
    }
  });

  it('passes other tests', async function() {
    assert.isTrue(await azimuth.isActive(0));
  });
});
