const Azimuth = artifacts.require('../contracts/Azimuth.sol');

const assertRevert = require('./helpers/assertRevert');
const seeEvents = require('./helpers/seeEvents');

const web3abi = require('web3-eth-abi');
const web3 = Azimuth.web3;

contract('Azimuth', function([owner, user, user2, user3]) {
  let azimuth;

  before('setting up for tests', async function() {
    azimuth = await Azimuth.new();
  });

  it('getting prefix', async function() {
    // galaxies
    assert.equal(await azimuth.getPrefix(0), 0);
    assert.equal(await azimuth.getPrefix(255), 255);
    // stars
    assert.equal(await azimuth.getPrefix(256), 0);
    assert.equal(await azimuth.getPrefix(65535), 255);
    // planets
    assert.equal(await azimuth.getPrefix(1245952), 768);
  });

  it('getting size', async function() {
    // galaxies
    assert.equal(await azimuth.getPointSize(0), 0);
    assert.equal(await azimuth.getPointSize(255), 0);
    // stars
    assert.equal(await azimuth.getPointSize(256), 1);
    assert.equal(await azimuth.getPointSize(65535), 1);
    // planets
    assert.equal(await azimuth.getPointSize(1245952), 2);
  });

  it('setting dns domain', async function() {
    // only owner can do this.
    await assertRevert(azimuth.setDnsDomains("new1", "new2", "new3", {from:user}));
    await azimuth.setDnsDomains("new1", "new2", "new3");
    assert.equal(await azimuth.dnsDomains(0), "new1");
    assert.equal(await azimuth.dnsDomains(1), "new2");
    assert.equal(await azimuth.dnsDomains(2), "new3");
  });

  it('getting and setting the point owner', async function() {
    assert.equal(await azimuth.getOwner(0), 0);
    // only owner can do this.
    await assertRevert(azimuth.setOwner(0, user, {from:user}));
    await seeEvents(azimuth.setOwner(0, user), ['OwnerChanged']);
    assert.isTrue(await azimuth.isOwner(0, user), true);
    assert.isFalse(await azimuth.isOwner(0, owner), false);
    // setting to the same owner is a no-op, shouldn't emit event
    await seeEvents(azimuth.setOwner(0, user), []);
  });

  it('getting owned points', async function() {
    await azimuth.setOwner(1, user);
    await azimuth.setOwner(2, user);
    let owned = await azimuth.getOwnedPoints(user);
    assert.equal(owned[0], 0);
    assert.equal(owned[1], 1);
    assert.equal(owned[2], 2);
    assert.equal(owned.length, 3);
    assert.equal(await azimuth.getOwnedPointAtIndex(user, 2), 2);
    await assertRevert(azimuth.getOwnedPointAtIndex(user, 3));
    await azimuth.setOwner(0, owner);
    owned = await azimuth.getOwnedPoints(user);
    assert.equal(owned[0].toNumber(), 2);
    assert.equal(owned[1].toNumber(), 1);
    assert.equal(owned.length, 2);
    // interact with points that got moved in the array
    await azimuth.setOwner(2, owner);
    owned = await azimuth.getOwnedPoints(user);
    assert.equal(owned[0].toNumber(), 1);
    assert.equal(owned.length, 1);
  });

  it('activating', async function() {
    assert.isFalse(await azimuth.isActive(0));
    assert.isFalse(await azimuth.isActive(257));
    // only owner can do this.
    await assertRevert(azimuth.activatePoint(0, {from:user}));
    await azimuth.activatePoint(0);
    await azimuth.activatePoint(257);
    assert.isTrue(await azimuth.isActive(0));
    assert.isTrue(await azimuth.isActive(257));
    assert.equal(await azimuth.getSponsor(257), 1);
    assert.isTrue(await azimuth.hasSponsor(257));
    assert.isTrue(await azimuth.isSponsor(257, 1));
    // can't do it twice.
    await assertRevert(azimuth.activatePoint(0));
    await azimuth.activatePoint(513);
    await azimuth.activatePoint(769);
  });

  it('spawning and spawn count', async function() {
    assert.equal(await azimuth.getSpawnCount(1), 0);
    // only owner can do this.
    await assertRevert(azimuth.registerSpawned(0, {from:user}));
    await azimuth.registerSpawned(257);
    assert.equal(await azimuth.getSpawnCount(1), 1);
    let spawned = await azimuth.getSpawned(1);
    assert.equal(spawned.length, 1);
    assert.equal(spawned[0], 257);
    // registering galaxy spawns is a no-op
    await azimuth.registerSpawned(1);
    assert.equal(await azimuth.getSpawnCount(1), 1);
    spawned = await azimuth.getSpawned(1);
    assert.equal(spawned.length, 1);
  });

  it('losing sponsor, setting, canceling, and doing escape', async function() {
    // reverse lookup is being kept correctly
    assert.equal(await azimuth.getSponsoringCount(1), 3);
    assert.equal(await azimuth.sponsoringIndexes(1, 257), 1);
    let spo = await azimuth.getSponsoring(1);
    assert.equal(spo[0], 257);
    assert.equal(spo[1], 513);
    assert.equal(spo[2], 769);
    // only owner can do this.
    await assertRevert(azimuth.loseSponsor(257, {from:user}));
    await seeEvents(azimuth.loseSponsor(257), ['LostSponsor']);
    assert.isFalse(await azimuth.hasSponsor(257));
    assert.isFalse(await azimuth.isSponsor(257, 1));
    assert.equal(await azimuth.getSponsor(257), 1);
    // won't emit events for subsequent calls.
    await seeEvents(azimuth.loseSponsor(257), []);
    assert.isFalse(await azimuth.isEscaping(257));
    // reverse lookup is being kept correctly
    assert.equal(await azimuth.getSponsoringCount(1), 2);
    assert.equal(await azimuth.sponsoringIndexes(1, 257), 0);
    spo = await azimuth.getSponsoring(1);
    assert.equal(spo[0], 769);
    assert.equal(spo[1], 513);
    // can still interact with points that got shuffled around in array
    await azimuth.loseSponsor(769);
    //
    // only owner can do this.
    await assertRevert(azimuth.setEscapeRequest(257, 2, {from:user}));
    // only owner can do this.
    await assertRevert(azimuth.cancelEscape(257, {from:user}));
    await seeEvents(azimuth.setEscapeRequest(257, 2), ['EscapeRequested']);
    assert.isTrue(await azimuth.isRequestingEscapeTo(257, 2));
    assert.isTrue(await azimuth.isEscaping(257));
    assert.equal(await azimuth.getEscapeRequest(257), 2);
    // setting to the same request is a no-op, shouldn't emit event
    await seeEvents(azimuth.setEscapeRequest(257, 2), []);
    // reverse lookup is being kept correctly
    await azimuth.setEscapeRequest(513, 2);
    await azimuth.setEscapeRequest(769, 2);
    assert.equal(await azimuth.getEscapeRequestsCount(2), 3);
    assert.equal(await azimuth.escapeRequestsIndexes(2, 257), 1);
    let esr = await azimuth.getEscapeRequests(2);
    assert.equal(esr[0], 257);
    assert.equal(esr[1], 513);
    assert.equal(esr[2], 769);
    // cancelling the escape
    await seeEvents(azimuth.cancelEscape(257), ['EscapeCanceled']);
    assert.isFalse(await azimuth.isRequestingEscapeTo(257, 2));
    assert.isFalse(await azimuth.isEscaping(257));
    // cancelling a non-escaping point is a no-op, shouldn't emit event
    await seeEvents(azimuth.cancelEscape(257), []);
    // reverse lookup is being kept correctly
    assert.equal(await azimuth.getEscapeRequestsCount(2), 2);
    assert.equal(await azimuth.escapeRequestsIndexes(2, 257), 0);
    esr = await azimuth.getEscapeRequests(2);
    assert.equal(esr[0], 769);
    assert.equal(esr[1], 513);
    // can still interact with points that got shuffled around in array
    await azimuth.cancelEscape(769);
    //
    // only owner can do this.
    await assertRevert(azimuth.doEscape(257, {from:user}));
    // can't do if not escaping.
    await assertRevert(azimuth.doEscape(257));
    await azimuth.setEscapeRequest(257, 2);
    await seeEvents(azimuth.doEscape(257), ['EscapeAccepted']);
    assert.isFalse(await azimuth.isRequestingEscapeTo(257, 2));
    assert.equal(await azimuth.getSponsor(257), 2);
  });

  it('setting keys', async function() {
    let { crypt, auth, suite, revision } = await azimuth.getKeys(0);
    assert.equal(crypt,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(suite, 0);
    assert.equal(revision, 0);
    assert.equal(await azimuth.getKeyRevisionNumber(0), 0);
    assert.isFalse(await azimuth.isLive(0));
    // only owner can do this.
    await assertRevert(azimuth.setKeys(web3.utils.toHex(0),
                                       web3.utils.toHex(10),
                                       web3.utils.toHex(11),
                                       web3.utils.toHex(2),
                                       {from:user}));
    await seeEvents(azimuth.setKeys(web3.utils.toHex(0),
                                    web3.utils.toHex(10),
                                    web3.utils.toHex(11),
                                    web3.utils.toHex(2)), ['ChangedKeys']);
    await seeEvents(azimuth.setKeys(web3.utils.toHex(0),
                                    web3.utils.toHex(10),
                                    web3.utils.toHex(11),
                                    web3.utils.toHex(2)), []);
    let ks = await azimuth.getKeys(web3.utils.toHex(0));
    crypt = ks.crypt;
    auth = ks.auth;
    suite = ks.suite;
    revision = ks.revision;
    assert.equal(crypt,
      '0x0a00000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0b00000000000000000000000000000000000000000000000000000000000000');
    assert.equal(suite, 2);
    assert.equal(revision, 1);
    assert.equal(await azimuth.getKeyRevisionNumber(0), 1);
    assert.equal(await azimuth.getContinuityNumber(0), 0);
    assert.isTrue(await azimuth.isLive(0));
    await azimuth.setKeys(web3.utils.toHex(0),
                          web3.utils.toHex(1),
                          web3.utils.toHex(0),
                          web3.utils.toHex(1));
    assert.isFalse(await azimuth.isLive(0));
    // only owner can do this
    await assertRevert(azimuth.incrementContinuityNumber(0, {from:user}));
    await azimuth.incrementContinuityNumber(0);
    assert.equal(await azimuth.getContinuityNumber(0), 1);
  });

  it('setting management proxy', async function() {
    assert.isFalse(await azimuth.isManagementProxy(0, owner));
    assert.equal(await azimuth.getManagerForCount(owner), 0);
    // only owner can do this.
    await assertRevert(azimuth.setManagementProxy(0, owner, {from:user}));
    await seeEvents(azimuth.setManagementProxy(0, owner), ['ChangedManagementProxy']);
    // won't emit event when nothing changes
    await seeEvents(azimuth.setManagementProxy(0, owner), []);
    await azimuth.setManagementProxy(1, owner);
    await azimuth.setManagementProxy(2, owner);
    assert.equal(await azimuth.getManagementProxy(0), owner);
    assert.isTrue(await azimuth.isManagementProxy(0, owner));
    assert.equal(await azimuth.getManagerForCount(owner), 3);
    assert.equal(await azimuth.managerForIndexes(owner, 0), 1);
    let stt = await azimuth.getManagerFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await azimuth.setManagementProxy(0, '0x0000000000000000000000000000000000000000');
    assert.isFalse(await azimuth.isManagementProxy(0, owner));
    assert.equal(await azimuth.getManagerForCount(owner), 2);
    assert.equal(await azimuth.managerForIndexes(owner, 0), 0);
    stt = await azimuth.getManagerFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with points that got shuffled around in array
    await azimuth.setManagementProxy(2, '0x0000000000000000000000000000000000000000');
  });

  it('setting voting proxy', async function() {
    assert.isFalse(await azimuth.isVotingProxy(0, owner));
    assert.equal(await azimuth.getVotingForCount(owner), 0);
    // only owner can do this.
    await assertRevert(azimuth.setVotingProxy(0, owner, {from:user}));
    await seeEvents(azimuth.setVotingProxy(0, owner), ['ChangedVotingProxy']);
    // won't emit event when nothing changes
    await seeEvents(azimuth.setVotingProxy(0, owner), []);
    await azimuth.setVotingProxy(1, owner);
    await azimuth.setVotingProxy(2, owner);
    assert.equal(await azimuth.getVotingProxy(0), owner);
    assert.isTrue(await azimuth.isVotingProxy(0, owner));
    assert.equal(await azimuth.getVotingForCount(owner), 3);
    assert.equal(await azimuth.votingForIndexes(owner, 0), 1);
    let stt = await azimuth.getVotingFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await azimuth.setVotingProxy(0, '0x0000000000000000000000000000000000000000');
    assert.isFalse(await azimuth.isVotingProxy(0, owner));
    assert.equal(await azimuth.getVotingForCount(owner), 2);
    assert.equal(await azimuth.votingForIndexes(owner, 0), 0);
    stt = await azimuth.getVotingFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with points that got shuffled around in array
    await azimuth.setVotingProxy(2, '0x0000000000000000000000000000000000000000');
  });

  it('setting spawn proxy', async function() {
    assert.isFalse(await azimuth.isSpawnProxy(0, owner));
    assert.equal(await azimuth.getSpawningForCount(owner), 0);
    // only owner can do this.
    await assertRevert(azimuth.setSpawnProxy(0, owner, {from:user}));
    await seeEvents(azimuth.setSpawnProxy(0, owner), ['ChangedSpawnProxy']);
    // won't emit event when nothing changes
    await seeEvents(azimuth.setSpawnProxy(0, owner), []);
    await azimuth.setSpawnProxy(1, owner);
    await azimuth.setSpawnProxy(2, owner);
    assert.equal(await azimuth.getSpawnProxy(0), owner);
    assert.isTrue(await azimuth.isSpawnProxy(0, owner));
    assert.equal(await azimuth.getSpawningForCount(owner), 3);
    assert.equal(await azimuth.spawningForIndexes(owner, 0), 1);
    let stt = await azimuth.getSpawningFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await azimuth.setSpawnProxy(0, '0x0000000000000000000000000000000000000000');
    assert.isFalse(await azimuth.isSpawnProxy(0, owner));
    assert.equal(await azimuth.getSpawningForCount(owner), 2);
    assert.equal(await azimuth.spawningForIndexes(owner, 0), 0);
    stt = await azimuth.getSpawningFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with points that got shuffled around in array
    await azimuth.setSpawnProxy(2, '0x0000000000000000000000000000000000000000');
  });

  it('setting transfer proxy', async function() {
    assert.isFalse(await azimuth.isTransferProxy(0, owner));
    assert.equal(await azimuth.getTransferringForCount(owner), 0);
    // only owner can do this.
    await assertRevert(azimuth.setTransferProxy(0, owner, {from:user}));
    await seeEvents(azimuth.setTransferProxy(0, owner), ['ChangedTransferProxy']);
    // won't emit event when nothing changes
    await seeEvents(azimuth.setTransferProxy(0, owner), []);
    await azimuth.setTransferProxy(1, owner);
    await azimuth.setTransferProxy(2, owner);
    assert.equal(await azimuth.getTransferProxy(0), owner);
    assert.isTrue(await azimuth.isTransferProxy(0, owner));
    assert.equal(await azimuth.getTransferringForCount(owner), 3);
    assert.equal(await azimuth.transferringForIndexes(owner, 0), 1);
    let stt = await azimuth.getTransferringFor(owner);
    assert.equal(stt[0], 0);
    assert.equal(stt[1], 1);
    assert.equal(stt[2], 2);
    await azimuth.setTransferProxy(0, '0x0000000000000000000000000000000000000000');
    assert.isFalse(await azimuth.isTransferProxy(0, owner));
    assert.equal(await azimuth.getTransferringForCount(owner), 2);
    assert.equal(await azimuth.transferringForIndexes(owner, 0), 0);
    stt = await azimuth.getTransferringFor(owner);
    assert.equal(stt[0], 2);
    assert.equal(stt[1], 1);
    // can still interact with points that got shuffled around in array
    await azimuth.setTransferProxy(2, '0x0000000000000000000000000000000000000000');
  });
});
