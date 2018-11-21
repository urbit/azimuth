const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Ecliptic = artifacts.require('../contracts/Ecliptic.sol');
const LSR = artifacts.require('../contracts/LinearStarRelease.sol');

const assertRevert = require('./helpers/assertRevert');
const increaseTime = require('./helpers/increaseTime');

contract('Linear Star Release', function([owner, user1, user2, user3]) {
  let azimuth, polls, eclipt, lsr, windup, rateUnit;

  before('setting up for tests', async function() {
    windup = 20;
    rateUnit = 50;
    azimuth = await Azimuth.new();
    polls = await Polls.new(432000, 432000);
    claims = await Claims.new(azimuth.address);
    eclipt = await Ecliptic.new(0, azimuth.address, polls.address,
                                     claims.address);
    await azimuth.transferOwnership(eclipt.address);
    await polls.transferOwnership(eclipt.address);
    await eclipt.createGalaxy(0, owner);
    await eclipt.configureKeys(0, 1, 2, 1, false);
    await eclipt.spawn(256, owner);
    await eclipt.spawn(2560, owner);
    await eclipt.configureKeys(2560, 1, 2, 1, false);
    lsr = await LSR.new(azimuth.address);
    await eclipt.setSpawnProxy(0, lsr.address);
    await eclipt.setTransferProxy(256, lsr.address);
  });

  it('registering batches', async function() {
    // only owner can do this
    await assertRevert(lsr.register(user1, windup, 5, 2, rateUnit, {from:user1}));
    // need a sane rate
    await assertRevert(lsr.register(user1, windup, 8, 0, rateUnit));
    assert.isTrue(await lsr.verifyBalance(user1));
    await lsr.register(user1, windup, 8, 2, rateUnit);
    await lsr.register(user3, windup, 8, 2, rateUnit);
    let bat = await lsr.batches(user1);
    assert.equal(bat[0], windup);
    assert.equal(bat[1], 2);
    assert.equal(bat[2], rateUnit);
    assert.equal(bat[3], 8);
    assert.equal(bat[4], 0);
    assert.isFalse(await lsr.verifyBalance(user1));
    // can always withdraw at least one star
    assert.equal(await lsr.withdrawLimit(user1), 1);
  });

  it('withdraw limit', async function() {
    // pass windup, still need to wait a rateUnit
    await increaseTime(windup);
    assert.equal(await lsr.withdrawLimit(user1), 1);
    // pass a rateUnit
    await increaseTime(rateUnit);
    assert.equal(await lsr.withdrawLimit(user1), 2);
    // pass two rateUnits
    await increaseTime(rateUnit);
    assert.equal(await lsr.withdrawLimit(user1), 4);
    // unregistered address should not yet have a withdraw limit
    try {
      await lsr.withdrawLimit(user2);
      assert.fail('should have thrown before');
    } catch(err) {
      assert.isAbove(err.message.search('invalid opcode'), -1, 'Invalid opcode must be returned, but got ' + err);
    }
  });

  it('depositing stars', async function() {
    // only owner can do this
    await assertRevert(lsr.deposit(user1, 256, {from:user1}));
    // can't deposit a live star
    await assertRevert(lsr.deposit(user1, 2560));
    // deposit spawned star, as star owner
    await lsr.deposit(user1, 256);
    // deposit unspawned stars, as galaxy owner
    for (var s = 2; s < 9; s++) {
      await lsr.deposit(user1, s*256);
    }
    assert.equal((await lsr.getRemainingStars(user1)).length, 8);
    assert.equal((await lsr.getRemainingStars(user1))[7], 2048);
    assert.isTrue(await azimuth.isOwner(256, lsr.address));
    assert.isTrue(await lsr.verifyBalance(user1));
    // can't deposit too many
    await assertRevert(lsr.deposit(user1, 2304));
  });

  it('transferring batch', async function() {
    assert.equal((await lsr.batches(user1))[5], 0);
    // can't transfer to other participant
    await assertRevert(lsr.approveBatchTransfer(user3, {from:user1}));
    // can't transfer without permission
    await assertRevert(lsr.transferBatch(user1, {from:user2}));
    await lsr.approveBatchTransfer(user2, {from:user1});
    await lsr.approveBatchTransfer(user2, {from:user3});
    assert.equal((await lsr.batches(user1))[5], user2);
    await lsr.transferBatch(user1, {from:user2});
    // can't if we became a participant in the mean time
    await assertRevert(lsr.transferBatch(user3, {from:user2}));
    await lsr.withdrawLimit(user2);
    // unregistered address should no longer have stars, etc
    assert.equal((await lsr.getRemainingStars(user1)).length, 0);
  });

  it('withdrawing', async function() {
    assert.equal(await lsr.withdrawLimit(user2), 4);
    // only commitment participant can do this
    await assertRevert(lsr.withdraw({from:owner}));
    await lsr.withdraw({from:user2});
    assert.isTrue(await azimuth.isOwner(2048, user2));
    assert.equal((await lsr.batches(user2))[4], 1);
    await lsr.withdraw({from:user2});
    await lsr.withdraw({from:user2});
    await lsr.withdraw({from:user2});
    assert.equal((await lsr.batches(user2))[4], 4);
    assert.equal(await lsr.withdrawLimit(user2), 4);
    // can't withdraw over limit
    await assertRevert(lsr.withdraw({from:user2}));
  });

  it('withdraw limit maximum', async function() {
    // pass all rateUnits, and then some
    await increaseTime(rateUnit * 100);
    assert.equal(await lsr.withdrawLimit(user2), 8);
  });

  it('escape hatch', async function() {
    await assertRevert(lsr.withdrawOverdue(user2, owner));
    await increaseTime(10*365*24*60*60);
    await lsr.withdrawOverdue(user2, owner);
    assert.isTrue(await azimuth.isOwner(1024, owner));
  });
});
