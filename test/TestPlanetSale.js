const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Ecliptic = artifacts.require('../contracts/Ecliptic.sol');
const PlanetSale = artifacts.require('../contracts/PlanetSale.sol');

const assertRevert = require('./helpers/assertRevert');

contract('Planet Sale', function([owner, user]) {
  let azimuth, polls, eclipt, sale, price;

  before('setting up for tests', async function() {
    price = 100000000;
    azimuth = await Azimuth.new();
    polls = await Polls.new(432000, 432000);
    claims = await Claims.new(azimuth.address);
    eclipt = await Ecliptic.new(0, azimuth.address, polls.address,
                                     claims.address);
    await azimuth.transferOwnership(eclipt.address);
    await polls.transferOwnership(eclipt.address);
    await eclipt.createGalaxy(0, owner);
    await eclipt.configureKeys(0, 10, 11, 1, false);
    await eclipt.spawn(256, owner);
    await eclipt.configureKeys(256, 12, 13, 1, false);
    sale = await PlanetSale.new(azimuth.address, price / 10);
  });

  it('configuring price', async function() {
    assert.equal(await sale.price(), price / 10);
    // only owner can do this.
    await assertRevert(sale.setPrice(price, {from:user}));
    // must be more than zero
    await assertRevert(PlanetSale.new(azimuth.address, 0));
    await assertRevert(sale.setPrice(0));
    await sale.setPrice(price);
    assert.equal(await sale.price(), price);
  });

  it('checking availability', async function() {
    assert.isFalse(await sale.available(65792));
    await eclipt.setSpawnProxy(256, sale.address);
    assert.isTrue(await sale.available(65792));
    assert.isFalse(await sale.available(65793));
  });

  it('purchasing', async function() {
    // can only purchase available planets.
    await assertRevert(sale.purchase(65793, {from:user,value:price}));
    // must pay the price
    await assertRevert(sale.purchase(65792, {from:user,value:price-1}));
    await sale.purchase(65792, {from:user,value:price});
    assert.isTrue(await azimuth.isOwner(65792, user));
    assert.isFalse(await sale.available(65792));
    assert.equal(await web3.eth.getBalance(sale.address), price);
    // can only purchase available planets.
    await assertRevert(sale.purchase(65792, {from:user,value:price}));
  });

  it('withdrawing', async function() {
    // only owner can do this.
    await assertRevert(sale.withdraw(user, {from:user}));
    // can't withdraw to zero address
    await assertRevert(sale.withdraw(0));
    let userBal = web3.eth.getBalance(user);
    let saleBal = web3.eth.getBalance(sale.address);
    let expected = userBal.add(saleBal);
    await sale.withdraw(user, {gasPrice:0});
    assert.isTrue(expected.eq(web3.eth.getBalance(user)));
  });

  it('ending', async function() {
    // only owner can do this.
    await assertRevert(sale.close(user, {from:user}));
    // can't send remaining funds to zero address
    await assertRevert(sale.close(0));
    await sale.purchase(131328, {from:user,value:price});
    let userBal = web3.eth.getBalance(user);
    let saleBal = web3.eth.getBalance(sale.address);
    let expected = userBal.add(saleBal);
    await sale.close(user, {gasPrice:0});
    assert.isTrue(expected.eq(web3.eth.getBalance(user)));
    // should no longer exist
    assert.equal(await web3.eth.getCode(sale.address), '0x');
  });
});
