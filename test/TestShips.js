const Ships = artifacts.require('../contracts/Ships.sol');

const assertRevert = require('./helpers/assertRevert');
const seeEvents = require('./helpers/seeEvents');

const web3abi = require('web3-eth-abi');
const web3 = Ships.web3;

contract('Ships', function([owner, user, user2, user3]) {
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
    await seeEvents(ships.setOwner(0, user), ['OwnerChanged']);
    assert.isTrue(await ships.isOwner(0, user), true);
    assert.isFalse(await ships.isOwner(0, owner), false);
    // setting to the same owner is a no-op, shouldn't emit event
    await seeEvents(ships.setOwner(0, user), []);
  });

  it('getting owned ships', async function() {
    await ships.setOwner(1, user);
    await ships.setOwner(2, user);
    let owned = await ships.getOwnedShipsByAddress(user);
    assert.equal(owned[0], 0);
    assert.equal(owned[1], 1);
    assert.equal(owned[2], 2);
    assert.equal(owned.length, 3);
    assert.equal(await ships.getOwnedShipAtIndex(user, 2), 2);
    await assertRevert(ships.getOwnedShipAtIndex(user, 3));
    await ships.setOwner(0, owner);
    owned = await ships.getOwnedShips({from:user});
    assert.equal(owned[0].toNumber(), 2);
    assert.equal(owned[1].toNumber(), 1);
    assert.equal(owned.length, 2);
    // interact with ships that got moved in the array
    await ships.setOwner(2, owner);
    owned = await ships.getOwnedShips({from:user});
    assert.equal(owned[0].toNumber(), 1);
    assert.equal(owned.length, 1);
  });

  it('activating', async function() {
    assert.isFalse(await ships.isActive(0));
    assert.isFalse(await ships.isActive(257));
    // only owner can do this.
    await assertRevert(ships.activateShip(0, {from:user}));
    await ships.activateShip(0);
    await ships.activateShip(257);
    assert.isTrue(await ships.isActive(0));
    assert.isTrue(await ships.isActive(257));
    assert.equal(await ships.getSponsor(257), 1);
    assert.isTrue(await ships.hasSponsor(257));
    assert.isTrue(await ships.isSponsor(257, 1));
    // can't do it twice.
    await assertRevert(ships.activateShip(0));
    await ships.activateShip(513);
    await ships.activateShip(769);
  });

  it('spawning and spawn count', async function() {
    assert.equal(await ships.getSpawnCount(1), 0);
    // only owner can do this.
    await assertRevert(ships.registerSpawned(0, {from:user}));
    await ships.registerSpawned(257);
    assert.equal(await ships.getSpawnCount(1), 1);
    let spawned = await ships.getSpawned(1);
    assert.equal(spawned.length, 1);
    assert.equal(spawned[0], 257);
    // registering galaxy spawns is a no-op
    await ships.registerSpawned(1);
    assert.equal(await ships.getSpawnCount(1), 1);
    spawned = await ships.getSpawned(1);
    assert.equal(spawned.length, 1);
  });

  it('losing sponsor, setting, canceling, and doing escape', async function() {
    // reverse lookup is being kept correctly
    assert.equal(await ships.getSponsoringCount(1), 3);
    assert.equal(await ships.sponsoringIndexes(1, 257), 1);
    let spo = await ships.getSponsoring(1);
    assert.equal(spo[0], 257);
    assert.equal(spo[1], 513);
    assert.equal(spo[2], 769);
    // only owner can do this.
    await assertRevert(ships.loseSponsor(257, {from:user}));
    await seeEvents(ships.loseSponsor(257), ['LostSponsor']);
    assert.isFalse(await ships.hasSponsor(257));
    assert.isFalse(await ships.isSponsor(257, 1));
    assert.equal(await ships.getSponsor(257), 1);
    // won't emit events for subsequent calls.
    await seeEvents(ships.loseSponsor(257), []);
    assert.isFalse(await ships.isEscaping(257));
    // reverse lookup is being kept correctly
    assert.equal(await ships.getSponsoringCount(1), 2);
    assert.equal(await ships.sponsoringIndexes(1, 257), 0);
    spo = await ships.getSponsoring(1);
    assert.equal(spo[0], 769);
    assert.equal(spo[1], 513);
    // can still interact with ships that got shuffled around in array
    await ships.loseSponsor(769);
    //
    // only owner can do this.
    await assertRevert(ships.setEscapeRequest(257, 2, {from:user}));
    // only owner can do this.
    await assertRevert(ships.cancelEscape(257, {from:user}));
    await seeEvents(ships.setEscapeRequest(257, 2), ['EscapeRequested']);
    assert.isTrue(await ships.isRequestingEscapeTo(257, 2));
    assert.isTrue(await ships.isEscaping(257));
    assert.equal(await ships.getEscapeRequest(257), 2);
    // setting to the same request is a no-op, shouldn't emit event
    await seeEvents(ships.setEscapeRequest(257, 2), []);
    // reverse lookup is being kept correctly
    await ships.setEscapeRequest(513, 2);
    await ships.setEscapeRequest(769, 2);
    assert.equal(await ships.getEscapeRequestsCount(2), 3);
    assert.equal(await ships.escapeRequestsIndexes(2, 257), 1);
    let esr = await ships.getEscapeRequests(2);
    assert.equal(esr[0], 257);
    assert.equal(esr[1], 513);
    assert.equal(esr[2], 769);
    // cancelling the escape
    await seeEvents(ships.cancelEscape(257), ['EscapeCanceled']);
    assert.isFalse(await ships.isRequestingEscapeTo(257, 2));
    assert.isFalse(await ships.isEscaping(257));
    // cancelling a non-escaping ship is a no-op, shouldn't emit event
    await seeEvents(ships.cancelEscape(257), []);
    // reverse lookup is being kept correctly
    assert.equal(await ships.getEscapeRequestsCount(2), 2);
    assert.equal(await ships.escapeRequestsIndexes(2, 257), 0);
    esr = await ships.getEscapeRequests(2);
    assert.equal(esr[0], 769);
    assert.equal(esr[1], 513);
    // can still interact with ships that got shuffled around in array
    await ships.cancelEscape(769);
    //
    // only owner can do this.
    await assertRevert(ships.doEscape(257, {from:user}));
    // can't do if not escaping.
    await assertRevert(ships.doEscape(257));
    await ships.setEscapeRequest(257, 2);
    await seeEvents(ships.doEscape(257), ['EscapeAccepted']);
    assert.isFalse(await ships.isRequestingEscapeTo(257, 2));
    assert.equal(await ships.getSponsor(257), 2);
  });

  it('setting keys', async function() {
    let [crypt, auth, suite, rev] = await ships.getKeys(0);
    assert.equal(crypt,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(suite, 0);
    assert.equal(rev, 0);
    assert.equal(await ships.getKeyRevisionNumber(0), 0);
    assert.isFalse(await ships.isLive(0));
    // only owner can do this.
    await assertRevert(ships.setKeys(0, 10, 11, 2, {from:user}));
    await seeEvents(ships.setKeys(0, 10, 11, 2), ['ChangedKeys']);
    await seeEvents(ships.setKeys(0, 10, 11, 2), []);
    [crypt, auth, suite, rev] = await ships.getKeys(0);
    assert.equal(crypt,
      '0xa000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0xb000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(suite, 2);
    assert.equal(rev, 1);
    assert.equal(await ships.getKeyRevisionNumber(0), 1);
    assert.equal(await ships.getContinuityNumber(0), 0);
    assert.isTrue(await ships.isLive(0));
    await ships.setKeys(0, 1, 0, 1);
    assert.isFalse(await ships.isLive(0));
    // only owner can do this
    await assertRevert(ships.incrementContinuityNumber(0, {from:user}));
    await ships.incrementContinuityNumber(0);
    assert.equal(await ships.getContinuityNumber(0), 1);
  });

  it('setting management proxy', async function() {
    assert.isFalse(await ships.isManagementProxy(0, owner));
    assert.equal(await ships.getManagerForCount(owner), 0);
    // only owner can do this.
    await assertRevert(ships.setManagementProxy(0, owner, {from:user}));
    await seeEvents(ships.setManagementProxy(0, owner), ['ChangedManagementProxy']);
    // won't emit event when nothing changes
    await seeEvents(ships.setManagementProxy(0, owner), []);
    await ships.setManagementProxy(1, owner);
    await ships.setManagementProxy(2, owner);
    assert.equal(await ships.getManagementProxy(0), owner);
    assert.isTrue(await ships.isManagementProxy(0, owner));
    assert.equal(await ships.getManagerForCount(owner), 3);
    assert.equal(await ships.managerForIndexes(owner, 0), 1);
    let stt = await ships.getManagerFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await ships.setManagementProxy(0, 0);
    assert.isFalse(await ships.isManagementProxy(0, owner));
    assert.equal(await ships.getManagerForCount(owner), 2);
    assert.equal(await ships.managerForIndexes(owner, 0), 0);
    stt = await ships.getManagerFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with ships that got shuffled around in array
    await ships.setManagementProxy(2, 0);
  });

  it('setting voting proxy', async function() {
    assert.isFalse(await ships.isVotingProxy(0, owner));
    assert.equal(await ships.getVotingForCount(owner), 0);
    // only owner can do this.
    await assertRevert(ships.setVotingProxy(0, owner, {from:user}));
    await seeEvents(ships.setVotingProxy(0, owner), ['ChangedVotingProxy']);
    // won't emit event when nothing changes
    await seeEvents(ships.setVotingProxy(0, owner), []);
    await ships.setVotingProxy(1, owner);
    await ships.setVotingProxy(2, owner);
    assert.equal(await ships.getVotingProxy(0), owner);
    assert.isTrue(await ships.isVotingProxy(0, owner));
    assert.equal(await ships.getVotingForCount(owner), 3);
    assert.equal(await ships.votingForIndexes(owner, 0), 1);
    let stt = await ships.getVotingFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await ships.setVotingProxy(0, 0);
    assert.isFalse(await ships.isVotingProxy(0, owner));
    assert.equal(await ships.getVotingForCount(owner), 2);
    assert.equal(await ships.votingForIndexes(owner, 0), 0);
    stt = await ships.getVotingFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with ships that got shuffled around in array
    await ships.setVotingProxy(2, 0);
  });

  it('setting spawn proxy', async function() {
    assert.isFalse(await ships.isSpawnProxy(0, owner));
    assert.equal(await ships.getSpawningForCount(owner), 0);
    // only owner can do this.
    await assertRevert(ships.setSpawnProxy(0, owner, {from:user}));
    await seeEvents(ships.setSpawnProxy(0, owner), ['ChangedSpawnProxy']);
    // won't emit event when nothing changes
    await seeEvents(ships.setSpawnProxy(0, owner), []);
    await ships.setSpawnProxy(1, owner);
    await ships.setSpawnProxy(2, owner);
    assert.equal(await ships.getSpawnProxy(0), owner);
    assert.isTrue(await ships.isSpawnProxy(0, owner));
    assert.equal(await ships.getSpawningForCount(owner), 3);
    assert.equal(await ships.spawningForIndexes(owner, 0), 1);
    let stt = await ships.getSpawningFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await ships.setSpawnProxy(0, 0);
    assert.isFalse(await ships.isSpawnProxy(0, owner));
    assert.equal(await ships.getSpawningForCount(owner), 2);
    assert.equal(await ships.spawningForIndexes(owner, 0), 0);
    stt = await ships.getSpawningFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with ships that got shuffled around in array
    await ships.setSpawnProxy(2, 0);
  });

  it('setting transfer proxy', async function() {
    assert.isFalse(await ships.isTransferProxy(0, owner));
    assert.equal(await ships.getTransferringForCount(owner), 0);
    // only owner can do this.
    await assertRevert(ships.setTransferProxy(0, owner, {from:user}));
    await seeEvents(ships.setTransferProxy(0, owner), ['ChangedTransferProxy']);
    // won't emit event when nothing changes
    await seeEvents(ships.setTransferProxy(0, owner), []);
    await ships.setTransferProxy(1, owner);
    await ships.setTransferProxy(2, owner);
    assert.equal(await ships.getTransferProxy(0), owner);
    assert.isTrue(await ships.isTransferProxy(0, owner));
    assert.equal(await ships.getTransferringForCount(owner), 3);
    assert.equal(await ships.transferringForIndexes(owner, 0), 1);
    let stt = await ships.getTransferringFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await ships.setTransferProxy(0, 0);
    assert.isFalse(await ships.isTransferProxy(0, owner));
    assert.equal(await ships.getTransferringForCount(owner), 2);
    assert.equal(await ships.transferringForIndexes(owner, 0), 0);
    stt = await ships.getTransferringFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with ships that got shuffled around in array
    await ships.setTransferProxy(2, 0);
  });
});
