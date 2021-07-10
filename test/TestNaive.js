const Naive = artifacts.require('Naive');

const seeEvents = require('./helpers/seeEvents');

const web3 = Naive.web3;

contract('Naive', function([owner, user]) {
  let naive;

  before('setting up for tests', async function() {
    naive = await Naive.new();
  });

  it('accepts batch', async function() {
    const tx = await web3.eth.sendTransaction({
      from: owner,
      to: naive.address,
      data: '0x1234',
    });
    assert.isTrue(tx.status);
  });
});
