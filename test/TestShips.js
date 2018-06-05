const Ships = artifacts.require('../contracts/Ships.sol');

const assertRevert = require('./helpers/assertRevert');

const web3abi = require('web3-eth-abi');
const web3 = Ships.web3;

contract('Ships', function([owner, user]) {
  let ships;

  before('setting up for tests', async function() {
    ships = await Ships.new();
  });

  it('getting prefix parent', async function() {
    // galaxies
    assert.equal(await ships.getPrefix(0), 0);
    assert.equal(await ships.getPrefix(255), 255);
    // stars
    assert.equal(await ships.getPrefix(256), 0);
    assert.equal(await ships.getPrefix(65535), 255);
    // planets
    assert.equal(await ships.getPrefix(1245952), 768);
  });

  it('getting class', async function() {
    // galaxies
    assert.equal(await ships.getShipClass(0), 0);
    assert.equal(await ships.getShipClass(255), 0);
    // stars
    assert.equal(await ships.getShipClass(256), 1);
    assert.equal(await ships.getShipClass(65535), 1);
    // planets
    assert.equal(await ships.getShipClass(1245952), 2);
  });

  it('setting dns domain', async function() {
    assert.equal(await ships.dnsDomains(0), "urbit.org");
    assert.equal(await ships.dnsDomains(1), "urbit.org");
    assert.equal(await ships.dnsDomains(2), "urbit.org");
    // only owner can do this.
    await assertRevert(ships.setDnsDomains("new1", "new2", "new3", {from:user}));
    await ships.setDnsDomains("new1", "new2", "new3");
    assert.equal(await ships.dnsDomains(0), "new1");
    assert.equal(await ships.dnsDomains(1), "new2");
    assert.equal(await ships.dnsDomains(2), "new3");
  });

  it('getting and setting the ship owner', async function() {
    assert.equal(await ships.getOwner(0), 0);
    // only owner can do this.
    await assertRevert(ships.setOwner(0, user, {from:user}));
    await ships.setOwner(0, user);
    // can't set to same owner.
    await assertRevert(ships.setOwner(0, user));
    assert.equal(await ships.isOwner(0, user), true);
    assert.equal(await ships.isOwner(0, owner), false);
  });

  it('getting owned ships', async function() {
    await ships.setOwner(1, user);
    await ships.setOwner(2, user);
    let owned = await ships.getOwnedShipsByAddress(user);
    assert.equal(owned[0], 0);
    assert.equal(owned[1], 1);
    assert.equal(owned[2], 2);
    assert.equal(owned.length, 3);
    await ships.setOwner(0, 0);
    owned = await ships.getOwnedShips({from:user});
    assert.equal(owned[0].toNumber(), 2);
    assert.equal(owned[1].toNumber(), 1);
    assert.equal(owned.length, 2);
  });

  it('activating and spawn count', async function() {
    assert.isFalse(await ships.isActive(0));
    assert.equal(await ships.getSpawnCount(1), 0);
    assert.isFalse(await ships.isActive(257));
    // only owner can do this.
    await assertRevert(ships.setActive(0, owner, {from:user}));
    await ships.setActive(0, owner);
    await ships.setActive(257, owner);
    assert.isTrue(await ships.isActive(0));
    assert.isTrue(await ships.isOwner(0, owner));
    assert.equal(await ships.getSpawnCount(1), 1);
    let spawned = await ships.getSpawned(1);
    assert.equal(spawned.length, 1);
    assert.equal(spawned[0], 257);
    assert.isTrue(await ships.isActive(257));
    assert.equal(await ships.getSponsor(257), 1);
    // can't do it twice.
    await assertRevert(ships.setActive(0, owner));
  });

  it('setting, canceling, and doing escape', async function() {
    assert.isFalse(await ships.isEscaping(257));
    // only owner can do this.
    await assertRevert(ships.setEscape(257, 2, {from:user}));
    // only owner can do this.
    await assertRevert(ships.cancelEscape(257, {from:user}));
    await ships.setEscape(257, 2);
    assert.isTrue(await ships.isEscape(257, 2));
    assert.isTrue(await ships.isEscaping(257));
    assert.equal(await ships.getEscape(257), 2);
    await ships.cancelEscape(257);
    assert.isFalse(await ships.isEscape(257, 2));
    assert.isFalse(await ships.isEscaping(257));
    // only owner can do this.
    await assertRevert(ships.doEscape(257, {from:user}));
    // can't do if not escaping.
    await assertRevert(ships.doEscape(257));
    await ships.setEscape(257, 2);
    await ships.doEscape(257);
    assert.isFalse(await ships.isEscape(257, 2));
    assert.equal(await ships.getSponsor(257), 2);
  });

  it('setting keys', async function() {
    let [crypt, auth] = await ships.getKeys(0);
    assert.equal(crypt,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await ships.getKeyRevisionNumber(0), 0);
    // only owner can do this.
    await assertRevert(ships.setKeys(0, 10, 11, {from:user}));
    await ships.setKeys(0, 10, 11);
    [crypt, auth] = await ships.getKeys(0);
    assert.equal(crypt,
      '0xa000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0xb000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await ships.getKeyRevisionNumber(0), 1);
    assert.equal(await ships.getContinuityNumber(0), 0);
    // only owner can do this
    await assertRevert(ships.incrementContinuityNumber(0, {from:user}));
    await ships.incrementContinuityNumber(0);
    assert.equal(await ships.getContinuityNumber(0), 1);
  });

  it('setting spawn proxy', async function() {
    assert.isFalse(await ships.isSpawnProxy(0, owner));
    assert.equal(await ships.getSpawnProxy(0), 0);
    // only owner can do this.
    await assertRevert(ships.setSpawnProxy(0, owner, {from:user}));
    await ships.setSpawnProxy(0, owner);
    assert.isTrue(await ships.isSpawnProxy(0, owner));
    assert.equal(await ships.getSpawnProxy(0), owner);
    await ships.setSpawnProxy(0, 0);
    assert.isFalse(await ships.isSpawnProxy(0, owner));
  });

  it('setting transfer proxy', async function() {
    assert.isFalse(await ships.isTransferProxy(0, owner));
    // only owner can do this.
    await assertRevert(ships.setTransferProxy(0, owner, {from:user}));
    await ships.setTransferProxy(0, owner);
    assert.isTrue(await ships.isTransferProxy(0, owner));
    await ships.setTransferProxy(0, 0);
    assert.isFalse(await ships.isTransferProxy(0, owner));
  });
});
