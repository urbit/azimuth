const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const PlanetSale = artifacts.require('../contracts/PlanetSale.sol');

contract('Planet Sale', function([owner, user]) {
  let ships, polls, constit, sale, price;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  function assertNoContract(error) {
    assert.isAbove(error.message.search('not a contract'), -1, 'Not a contract must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    price = 100000000;
    ships = await Ships.new();
    polls = await Polls.new(0, 0);
    claims = await Claims.new(ships.address);
    constit = await Constitution.new(0, ships.address, polls.address,
                                     0, '', '', claims.address);
    await ships.transferOwnership(constit.address);
    await polls.transferOwnership(constit.address);
    await constit.createGalaxy(0, owner);
    await constit.configureKeys(0, 10, 11, false);
    await constit.spawn(256, owner);
    await constit.configureKeys(256, 12, 13, false);
    sale = await PlanetSale.new(ships.address, price / 10);
  });

  it('configuring price', async function() {
    assert.equal(await sale.price(), price / 10);
    // only owner can do this.
    try {
      await sale.setPrice(price, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await sale.setPrice(price);
    assert.equal(await sale.price(), price);
  });

  it('checking availability', async function() {
    assert.isFalse(await sale.available(65792));
    await constit.setSpawnProxy(256, sale.address);
    assert.isTrue(await sale.available(65792));
    assert.isFalse(await sale.available(65793));
  });

  it('purchasing', async function() {
    // can only purchase available planets.
    try {
      await sale.purchase(65793, {from:user,value:price});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // must pay the price
    try {
      await sale.purchase(65792, {from:user,value:price-1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await sale.purchase(65792, {from:user,value:price});
    assert.isTrue(await ships.isOwner(65792, user));
    assert.isFalse(await sale.available(65792));
    assert.equal(await web3.eth.getBalance(sale.address), price);
    // can only purchase available planets.
    try {
      await sale.purchase(65792, {from:user,value:price});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
  });

  it('withdrawing', async function() {
    // only owner can do this.
    try {
      await sale.withdraw(user, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    let userBal = web3.eth.getBalance(user).toNumber();
    let saleBal = web3.eth.getBalance(sale.address).toNumber();
    await sale.withdraw(user);
    assert.equal(web3.eth.getBalance(user).toNumber(), userBal + saleBal);
  });

  it('ending', async function() {
    // only owner can do this.
    try {
      await sale.close(user, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await sale.purchase(131328, {from:user,value:price});
    let userBal = web3.eth.getBalance(user).toNumber();
    let saleBal = web3.eth.getBalance(sale.address).toNumber();
    await sale.close(user);
    assert.equal(web3.eth.getBalance(user).toNumber(), userBal + saleBal);
    // should no longer exist
    try {
      await sale.price();
      assert.fail('should have thrown before');
    } catch(err) {
      assertNoContract(err);
    }
  });
});
