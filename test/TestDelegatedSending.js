const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Ecliptic = artifacts.require('../contracts/Ecliptic.sol');
const DelegatedSending = artifacts.require('../contracts/DelegatedSending.sol');

const assertRevert = require('./helpers/assertRevert');
const seeEvents = require('./helpers/seeEvents');

contract('Delegated Sending', function([owner, user1, user2, user3, user4]) {
  let azimuth, eclipt, dese;
  let p1, p2, p3, p4, p5;

  before('setting up for tests', async function() {
    p1 = 65792;
    p2 = 131328;
    p3 = 196864;
    p4 = 262400;
    p5 = 327936;
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
    await eclipt.spawn(256, owner);
    await eclipt.configureKeys(256, 1, 1, 1, false);
    await eclipt.spawn(p1, owner);
    await eclipt.transferPoint(p1, owner, false);
    await eclipt.setSpawnProxy(256, dese.address);
  });

  it('configuring', async function() {
    assert.equal(await dese.limits(256), 0);
    assert.isFalse(await dese.canSend(p1, p2));
    // can only be done by star owner.
    await assertRevert(dese.configureLimit(256, 1, {from:user1}));
    await dese.configureLimit(256, 3);
    assert.equal(await dese.limits(256), 3);
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
    await dese.sendPoint(p2, p3, user2, {from:user1});
    await eclipt.transferPoint(p3, user2, true);
    await dese.sendPoint(p3, p4, user3, {from:user2});
    await eclipt.transferPoint(p4, user3, true);
    // can't send more than the limit
    assert.isFalse(await dese.canSend(p1, p5));
    assert.isFalse(await dese.canSend(p3, p5));
    await assertRevert(dese.sendPoint(p3, p5, user4));
  });

  it('resetting a pool', async function() {
    // can only be done by owner of the target's prefix
    await assertRevert(dese.resetPool(p3, {from:user1}));
    await dese.resetPool(p3);
    assert.isTrue(await dese.canSend(p3, p5));
    // shouldn't affect the pool it came from
    assert.isFalse(await dese.canSend(p1, p5));
    await dese.sendPoint(p3, p5, user4, {from:user2});
  });
});
