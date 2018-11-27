const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Ecliptic = artifacts.require('../contracts/Ecliptic.sol');
const ENSRegistry = artifacts.require('../contracts/ENSRegistry.sol');
const PublicResolver = artifacts.require('../contracts/PublicResolver.sol');

const assertRevert = require('./helpers/assertRevert');
const increaseTime = require('./helpers/increaseTime');
const seeEvents = require('./helpers/seeEvents');

contract('Ecliptic', function([owner, user1, user2]) {
  let azimuth, polls, claims, ens, resolver, eclipt, eclipt2, pollTime;

  before('setting up for tests', async function() {
    pollTime = 432000;
    azimuth = await Azimuth.new();
    polls = await Polls.new(pollTime, pollTime);
    claims = await Claims.new(azimuth.address);
    eclipt = await Ecliptic.new(0, azimuth.address, polls.address,
                                   claims.address);
    await azimuth.transferOwnership(eclipt.address);
    await polls.transferOwnership(eclipt.address);
  });

  it('setting dns domains', async function() {
    // can only be done by owner
    await assertRevert(eclipt.setDnsDomains("1", "2", "3", {from:user1}));
    await eclipt.setDnsDomains("1", "2", "3");
    assert.equal(await azimuth.dnsDomains(2), "3");
  });

  it('creating galaxies', async function() {
    // create.
    await eclipt.createGalaxy(0, user1);
    assert.isFalse(await azimuth.isActive(0));
    assert.isTrue(await azimuth.isOwner(0, owner));
    assert.isTrue(await azimuth.isTransferProxy(0, user1));
    // can't create twice.
    await assertRevert(eclipt.createGalaxy(0, owner));
    // non-owner can't create.
    await assertRevert(eclipt.createGalaxy(1, user1, {from:user1}));
    // prep for next tests.
    await eclipt.transferPoint(0, user1, false, {from:user1});
    await eclipt.createGalaxy(1, user1);
    await eclipt.transferPoint(1, user1, false, {from:user1});
    await eclipt.createGalaxy(2, owner);
    assert.isTrue(await azimuth.isActive(2));
    assert.isTrue(await azimuth.isOwner(2, owner));
    assert.equal(await polls.totalVoters(), 3);
    await eclipt.transferPoint(2, user1, false);
  });

  it('spawning points', async function() {
    // can't spawn if prefix not live.
    await assertRevert(eclipt.spawn(256, user1, {from:user1}));
    await eclipt.configureKeys(0, 1, 2, 1, false, {from:user1});
    // can't spawn if not prefix owner.
    await assertRevert(eclipt.spawn(256, user1, {from:user2}));
    // can only spawn size directly below prefix
    await assertRevert(eclipt.spawn(65536, user1), {from:user1});
    // spawn child to self, directly
    assert.isFalse(await azimuth.isOwner(256, user1));
    await seeEvents(eclipt.spawn(256, user1, {from:user1}),
                    ['Transfer']);
    assert.equal(await azimuth.getSpawnCount(0), 1);
    assert.isTrue(await azimuth.isOwner(256, user1));
    assert.isTrue(await azimuth.isActive(256));
    // can't spawn same point twice.
    await assertRevert(eclipt.spawn(256, user1, {from:user1}));
    // spawn child to other, via withdraw pattern
    await seeEvents(eclipt.spawn(512, user2, {from:user1}),
                    ['Transfer', 'Approval']);
    assert.equal(await azimuth.getSpawnCount(0), 2);
    assert.isTrue(await azimuth.isOwner(512, user1));
    assert.isFalse(await azimuth.isActive(512));
    assert.isTrue(await azimuth.isTransferProxy(512, user2));
    await eclipt.transferPoint(512, user2, true, {from:user2});
    assert.isTrue(await azimuth.isOwner(512, user2));
    assert.isTrue(await azimuth.isActive(512));
    await eclipt.transferPoint(512, user1, true, {from:user2});
    // check the spawn limits.
    assert.equal(await eclipt.getSpawnLimit(0, 0), 255);
    assert.equal(await eclipt.getSpawnLimit(123455, 0), 0);
    assert.equal(await eclipt.getSpawnLimit(512, new Date('2019-01-01 UTC').valueOf() / 1000), 1024);
    assert.equal(await eclipt.getSpawnLimit(512, new Date('2019-12-31 UTC').valueOf() / 1000), 1024);
    assert.equal(await eclipt.getSpawnLimit(512, new Date('2020-01-01 UTC').valueOf() / 1000), 2048);
    assert.equal(await eclipt.getSpawnLimit(512, new Date('2024-01-01 UTC').valueOf() / 1000), 32768);
    assert.equal(await eclipt.getSpawnLimit(512, new Date('2025-01-01 UTC').valueOf() / 1000), 65535);
    assert.equal(await eclipt.getSpawnLimit(512, new Date('2026-01-01 UTC').valueOf() / 1000), 65535);
  });

  it('setting spawn proxy', async function() {
    // should not be spawner by default.
    assert.isFalse(await azimuth.isSpawnProxy(0, user2));
    // can't do if not owner.
    await assertRevert(eclipt.setSpawnProxy(0, user2, {from:user2}));
    // set up for working spawn.
    await eclipt.setSpawnProxy(0, user2, {from:user1});
    assert.isTrue(await azimuth.isSpawnProxy(0, user2));
    // spawn as launcher, then test revoking of rights.
    await eclipt.spawn(768, user1, {from:user2});
    await eclipt.setSpawnProxy(0, 0, {from:user1});
    assert.isFalse(await azimuth.isSpawnProxy(0, user2));
  });

  it('transfering ownership directly', async function() {
    assert.equal(await azimuth.getContinuityNumber(0), 0);
    // set values that should be cleared on-transfer.
    await eclipt.setManagementProxy(0, owner, {from:user1});
    await eclipt.setVotingProxy(0, owner, {from:user1});
    await eclipt.setSpawnProxy(0, owner, {from:user1});
    await eclipt.setTransferProxy(0, owner, {from:user1});
    await claims.addClaim(0, "protocol", "claim", "proof", {from:user1});
    // can't do if not owner.
    await assertRevert(eclipt.transferPoint(0, user2, true, {from:user2}));
    // transfer as owner, resetting the point.
    await seeEvents(eclipt.transferPoint(0, user2, true, {from:user1}),
                    ['Transfer']);
    assert.isTrue(await azimuth.isOwner(0, user2));
    let [crypt, auth] = await azimuth.getKeys(0);
    assert.equal(crypt,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await azimuth.getKeyRevisionNumber(0), 2);
    assert.equal(await azimuth.getContinuityNumber(0), 1);
    assert.isTrue(await azimuth.isManagementProxy(0, 0));
    assert.isTrue(await azimuth.isVotingProxy(0, 0));
    assert.isTrue(await azimuth.isSpawnProxy(0, 0));
    assert.isTrue(await azimuth.isTransferProxy(0, 0));
    let claim = await claims.claims(0, 0);
    assert.equal(claim[0], "");
    // for unlinked points, keys/continuity aren't incremented
    assert.equal(await azimuth.getKeyRevisionNumber(2), 0);
    assert.equal(await azimuth.getContinuityNumber(2), 0);
    await eclipt.transferPoint(2, user2, true, {from:user1});
    assert.equal(await azimuth.getKeyRevisionNumber(2), 0);
    assert.equal(await azimuth.getContinuityNumber(2), 0);
    // transfer to self as temporary owner of spawned point
    assert.isTrue(await azimuth.isTransferProxy(768, user1));
    // this shouldn't have emitted a transfer event
    await seeEvents(eclipt.transferPoint(768, user1, true, {from:user1}), []);
    // but still reset proxy because we asked
    assert.isTrue(await azimuth.isTransferProxy(768, 0));
  });

  it('allowing transfer of ownership', async function() {
    // can't do if not owner.
    await assertRevert(eclipt.setTransferProxy(0, user1, {from:user1}));
    // allow as owner.
    await seeEvents(eclipt.setTransferProxy(0, user1, {from:user2}),
                    ['Approval']);
    await eclipt.setSpawnProxy(0, user1, {from:user2});
    assert.isTrue(await azimuth.isTransferProxy(0, user1));
    // transfer as transferrer, but don't reset.
    await eclipt.transferPoint(0, user1, false, {from:user1});
    assert.isTrue(await azimuth.isOwner(0, user1));
    assert.isTrue(await azimuth.isSpawnProxy(0, user1));
    // transferrer always reset on-transfer, as per erc721
    assert.isFalse(await azimuth.isTransferProxy(0, user1));
  });

  it('rekeying a point', async function() {
    // can't do if not owner.
    await assertRevert(eclipt.configureKeys(0, 9, 8, 1, false, {from:user2}));
    // can't do if point not active.
    await assertRevert(eclipt.configureKeys(100, 9, 8, 1, false));
    // rekey as owner.
    await eclipt.configureKeys(0, 9, 8, 1, false, {from:user1});
    let [crypt, auth, suite, rev] = await azimuth.getKeys(0);
    assert.equal(crypt,
      '0x9000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x8000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(suite, 1);
    assert.equal(rev, 3);
    assert.equal(await azimuth.getKeyRevisionNumber(0), 3);
    await eclipt.configureKeys(0, 9, 8, 1, true, {from:user1});
    assert.equal(await azimuth.getContinuityNumber(0), 2);
  });

  it('setting management proxy', async function() {
    assert.equal(await azimuth.getManagementProxy(0), 0);
    await eclipt.setManagementProxy(0, owner, {from:user1});
    assert.equal(await azimuth.getManagementProxy(0), owner);
    // manager can do things like configure keys
    await eclipt.configureKeys(0, 9, 9, 1, false, {from:owner});
  });

  it('setting and canceling an escape', async function() {
    // can't if chosen sponsor not active.
    await assertRevert(eclipt.escape(257, 1, {from:user1}));
    await eclipt.configureKeys(1, 8, 9, 1, false, {from:user1});
    // can't if not owner of point.
    await assertRevert(eclipt.escape(256, 1, {from:user2}));
    await assertRevert(eclipt.cancelEscape(256, {from:user2}));
    // galaxies can't escape.
    await assertRevert(eclipt.escape(0, 1, {from:user1}));
    // set escape as owner.
    await eclipt.escape(256, 1, {from:user1});
    assert.isTrue(await azimuth.isRequestingEscapeTo(256, 1));
    await eclipt.cancelEscape(256, {from:user1});
    assert.isFalse(await azimuth.isRequestingEscapeTo(256, 1));
    await eclipt.escape(256, 1, {from:user1});
    await eclipt.escape(512, 1, {from:user1});
    // try out peer sponsorship.
    await eclipt.configureKeys(256, 1, 2, 1, false, {from:user1});
    await eclipt.spawn(65792, owner, {from:user1});
    await eclipt.transferPoint(65792, owner, true);
    await eclipt.spawn(131328, owner, {from:user1});
    await eclipt.transferPoint(131328, owner, true);
    assert.isFalse(await eclipt.canEscapeTo(131328, 65792));
    await eclipt.configureKeys(65792, 1, 2, 1, false);
    assert.isTrue(await eclipt.canEscapeTo(131328, 65792));
    await eclipt.configureKeys(131328, 3, 4, 1, false);
    assert.isFalse(await eclipt.canEscapeTo(131328, 65792));
  });

  it('adopting or reject an escaping point', async function() {
    // can't if not owner of sponsor.
    await assertRevert(eclipt.adopt(256, {from:user2}));
    await assertRevert(eclipt.reject(512, {from:user2}));
    // can't if target is not escaping to sponsor.
    await assertRevert(eclipt.adopt(258, {from:user1}));
    await assertRevert(eclipt.reject(258, {from:user1}));
    // adopt as sponsor owner.
    await eclipt.adopt(256, {from:user1});
    assert.isFalse(await azimuth.isRequestingEscapeTo(256, 1));
    assert.equal(await azimuth.getSponsor(256), 1);
    assert.isTrue(await azimuth.isSponsor(256, 1));
    // reject as sponsor owner.
    await eclipt.reject(512, {from:user1});
    assert.isFalse(await azimuth.isRequestingEscapeTo(512, 1));
    assert.equal(await azimuth.getSponsor(512), 0);
  });

  it('detaching sponsorship', async function() {
    // can't if not owner of sponsor
    await assertRevert(eclipt.detach(256, {from:user2}));
    await eclipt.detach(256, {from:user1});
    assert.isFalse(await azimuth.isSponsor(256, 1));
    assert.equal(await azimuth.getSponsor(256), 1);
  });

  it('setting voting proxy', async function() {
    assert.equal(await azimuth.getVotingProxy(0), 0);
    await eclipt.setVotingProxy(0, owner, {from:user1});
    assert.equal(await azimuth.getVotingProxy(0), owner);
  });

  it('voting on and updating document poll', async function() {
    // can't if not galaxy owner.
    await assertRevert(eclipt.startDocumentPoll(0, 10, {from:user2}));
    await assertRevert(eclipt.castDocumentVote(0, 10, true, {from:user2}));
    await eclipt.startDocumentPoll(0, 10, {from:user1});
    // can do voting operations as delegate
    await eclipt.castDocumentVote(0, 10, true);
    assert.isTrue(await polls.hasVotedOnDocumentPoll(0, 10));
    await increaseTime(pollTime + 5);
    await eclipt.updateDocumentPoll(10);
    assert.isTrue(await polls.documentHasAchievedMajority(10));
  });

  it('voting on upgrade poll', async function() {
    ecliptx = await Ecliptic.new('0x0',
                                     azimuth.address,
                                     polls.address,
                                     claims.address);
    eclipt2 = await Ecliptic.new(eclipt.address,
                                     azimuth.address,
                                     polls.address,
                                     claims.address);
    // can't if upgrade path not correct
    await assertRevert(eclipt.startUpgradePoll(0, ecliptx.address, {from:user1}));
    // can't start if not galaxy owner.
    await assertRevert(eclipt.startUpgradePoll(0, eclipt2.address, {from:user2}));
    await eclipt.startUpgradePoll(0, eclipt2.address, {from:user1});
    // can't vote if not galaxy owner
    await assertRevert(eclipt.castUpgradeVote(0, eclipt2.address, true, {from:user2}));
    await eclipt.castUpgradeVote(0, eclipt2.address, true, {from:user1});
    await eclipt.castUpgradeVote(1, eclipt2.address, true, {from:user1});
    assert.equal(await azimuth.owner(), eclipt2.address);
    assert.equal(await polls.owner(), eclipt2.address);
  });

  it('updating upgrade poll', async function() {
    let eclipt3 = await Ecliptic.new(eclipt2.address,
                                         azimuth.address,
                                         polls.address,
                                         claims.address);
    // onUpgrade can only be called by previous ecliptic
    await assertRevert(eclipt3.onUpgrade({from:user2}));
    assert.equal(await azimuth.owner(), eclipt2.address);
    await eclipt2.startUpgradePoll(0, eclipt3.address, {from:user1});
    await eclipt2.castUpgradeVote(0, eclipt3.address, true, {from:user1});
    await seeEvents(eclipt2.updateUpgradePoll(eclipt3.address), []);
    assert.equal(await azimuth.owner(), eclipt2.address);
    await increaseTime(pollTime + 5);
    await seeEvents(eclipt2.updateUpgradePoll(eclipt3.address),
                    ['Upgraded', 'OwnershipTransferred']);
    assert.equal(await azimuth.owner(), eclipt3.address);
    assert.equal(await polls.owner(), eclipt3.address);
  });
});
