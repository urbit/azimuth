const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Ecliptic = artifacts.require('../contracts/Ecliptic.sol');
const DelegatedSending = artifacts.require('../contracts/DelegatedSending.sol');

const assertRevert = require('./helpers/assertRevert');
const seeEvents = require('./helpers/seeEvents');

contract('Delegated Sending', function([owner, user1, user2, user3, user4, user5]) {
  let azimuth, eclipt, dese;
  let p1, p2, p3, p4, p5;

  before('setting up for tests', async function() {
    s1 = 256;
    s2 = 512;
    p1 = 65792;
    p2 = 131328;
    p3 = 196864;
    p4 = 262400;
    p5 = 327936;
    p6 = 66048;
    //
    azimuth = await Azimuth.new();
    polls = await Polls.new(432000, 432000);
    claims = await Claims.new(azimuth.address);
    eclipt = await Ecliptic.new(0, azimuth.address, polls.address,
                                     claims.address);
    await azimuth.transferOwnership(eclipt.address);
    await polls.transferOwnership(eclipt.address);
    dese = await DelegatedSending.new(azimuth.address);
    //
    await eclipt.createGalaxy(0, owner);
    await eclipt.configureKeys(0, 1, 1, 1, false);
    await eclipt.spawn(s1, owner);
    await eclipt.configureKeys(s1, 1, 1, 1, false);
    await eclipt.setSpawnProxy(s1, dese.address);
    await eclipt.spawn(s2, owner);
    await eclipt.configureKeys(s2, 1, 1, 1, false);
    await eclipt.setSpawnProxy(s2, dese.address);
    await eclipt.spawn(p1, owner);
    await eclipt.transferPoint(p1, owner, false);
  });

  it('configuring', async function() {
    assert.equal(await dese.pools(p1, s1), 0);
    assert.isFalse(await dese.canSend(p1, p2));
    // can only be done by owner of any star
    await assertRevert(dese.setPoolSize(s1, p1, 3, {from:user1}));
    await dese.setPoolSize(s1, p1, 3);
    await dese.setPoolSize(s2, p1, 9);
    let poolStars = await dese.getPoolStars(p1);
    assert.equal(poolStars.length, 2);
    assert.equal(poolStars[0], s1);
    assert.equal(poolStars[1], s2);
    assert.equal(await dese.pools(p1, s1), 3);
    assert.equal(await dese.pools(p1, s2), 9);
    let inviters = await dese.getInviters();
    assert.equal(inviters.length, 1);
    assert.equal(inviters[0], p1);
    assert.isTrue(await dese.canSend(p1, p2));
  });

  it('sending', async function() {
    // can only be done by point owner
    await assertRevert(dese.sendPoint(p1, p2, user1, {from:user1}));
    // can't send to self
    await assertRevert(dese.sendPoint(p1, p2, owner));
    // send as regular planet
    assert.isTrue(await dese.canReceive(user1));
    await seeEvents(dese.sendPoint(p1, p2, user1), ['Sent']);
    assert.isTrue(await azimuth.isTransferProxy(p2, user1));
    assert.equal(await dese.pools(p1, s1), 2);
    assert.equal(await dese.fromPool(p2), p1);
    let invited = await dese.getInvited(p1);
    assert.equal(invited.length, 1);
    assert.equal(invited[0], p2);
    assert.equal(await dese.invitedBy(p2), p1);
    assert.isFalse(await dese.canSend(p1, p2));
    await assertRevert(dese.sendPoint(p1, p2, user1));
    // can't send to users with pending transfers
    assert.isFalse(await dese.canReceive(user1));
    await assertRevert(dese.sendPoint(p2, p3, user1));
    await eclipt.transferPoint(p2, user1, true);
    assert.isFalse(await dese.canSend(p1, p2));
    // can't send to users who own points
    assert.isFalse(await dese.canReceive(user1));
    await assertRevert(dese.sendPoint(p1, p3, user1));
    // send as invited planet
    assert.equal(await dese.getPool(p3), p3);
    await dese.sendPoint(p2, p3, user2, {from:user1});
    assert.equal(await dese.pools(p1, s1), 1);
    assert.equal(await dese.fromPool(p3), p1);
    assert.equal(await dese.getPool(p3), p1);
    invited = await dese.getInvited(p2);
    assert.equal(invited.length, 1);
    assert.equal(invited[0], p3);
    assert.equal(await dese.invitedBy(p3), p2);
    await eclipt.transferPoint(p3, user2, true);
    await dese.sendPoint(p3, p4, user3, {from:user2});
    assert.equal(await dese.pools(p1, s1), 0);
    await eclipt.transferPoint(p4, user3, true);
    // can't send once pool depleted
    assert.isFalse(await dese.canSend(p1, p5));
    assert.isFalse(await dese.canSend(p3, p5));
    await assertRevert(dese.sendPoint(p3, p5, user4));
    // but can still send from other pool, even as invitee
    assert.isTrue(await dese.canSend(p1, p6));
    assert.isTrue(await dese.canSend(p3, p6));
    await dese.sendPoint(p3, p6, user4, {from:user2});
    assert.equal(await dese.pools(p1, s2), 8);
  });

  it('resetting an invitee\'s pool', async function() {
    await dese.setPoolSize(s1, p3, 3);
    assert.isTrue(await dese.canSend(p3, p5));
    // shouldn't affect the pool it came from
    assert.isFalse(await dese.canSend(p1, p5));
    await dese.sendPoint(p3, p5, user5, {from:user2});
  });
});
