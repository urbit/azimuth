const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const LSR = artifacts.require('../contracts/LinearStarRelease.sol');

contract('Linear Star Release', function([owner, user1, user2, user3]) {
  let ships, polls, constit, lsr, windup, rateUnit;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  function assertInvalid(error) {
    assert.isAbove(error.message.search('invalid opcode'), -1, 'Invalid opcode must be returned, but got ' + error);
  }

  // because setTimeout doesn't work.
  function busywait(s) {
    var start = Date.now();
    var ms = s * 1000;
    while (true) {
      if ((Date.now() - start) > ms) break;
    }
  }

  function busywaitUntil(timestamp) {
    var ms = timestamp * 1000;
    while (true) {
      if (Date.now() > ms) break;
    }
  }

  before('setting up for tests', async function() {
    windup = 2;
    rateUnit = 4;
    ships = await Ships.new();
    polls = await Polls.new(60, 0);
    claims = await Claims.new(ships.address);
    constit = await Constitution.new(0, ships.address, polls.address,
                                     0, '', '', claims.address);
    await ships.transferOwnership(constit.address);
    await polls.transferOwnership(constit.address);
    await constit.createGalaxy(0, owner);
    await constit.configureKeys(0, 1, 2, false);
    await constit.spawn(256, owner);
    await constit.spawn(2560, owner);
    await constit.configureKeys(2560, 1, 2, false);
    lsr = await LSR.new(ships.address);
    await constit.setSpawnProxy(0, lsr.address);
    await constit.setTransferProxy(256, lsr.address);
  });

  it('registering batches', async function() {
    // only owner can do this
    try {
      await lsr.register(user1, windup, 5, 2, rateUnit, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // need a sane rate
    try {
      await lsr.register(user1, windup, 8, 0, rateUnit);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
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
    busywait(windup);
    assert.equal(await lsr.withdrawLimit(user1), 1);
    // pass a rateUnit
    busywait(rateUnit);
    assert.equal(await lsr.withdrawLimit(user1), 2);
    // pass two rateUnits
    busywait(rateUnit);
    assert.equal(await lsr.withdrawLimit(user1), 4);
    // unregistered address should not yet have a withdraw limit
    try {
      await lsr.withdrawLimit(user2);
      assert.fail('should have thrown before');
    } catch(err) {
      assertInvalid(err);
    }
  });

  it('depositing stars', async function() {
    // only owner can do this
    try {
      await lsr.deposit(user1, 256, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't deposit a live star
    try {
      await lsr.deposit(user1, 2560);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // deposit spawned star, as star owner
    await lsr.deposit(user1, 256);
    // deposit unspawned stars, as galaxy owner
    for (var s = 2; s < 9; s++) {
      await lsr.deposit(user1, s*256);
    }
    assert.equal((await lsr.getRemainingStars(user1)).length, 8);
    assert.equal((await lsr.getRemainingStars(user1))[7], 2048);
    assert.isTrue(await ships.isOwner(256, lsr.address));
    assert.isTrue(await lsr.verifyBalance(user1));
    // can't deposit too many
    try {
      await lsr.deposit(user1, 2304);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
  });

  it('transferring batch', async function() {
    assert.equal(await lsr.transfers(user1), 0);
    assert.notEqual(await lsr.getRemainingStars(user1), 0);
    assert.equal(await lsr.getRemainingStars(user2), 0);
    // can't transfer to other participant
    try {
      await lsr.approveBatchTransfer(user3, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't transfer without permission
    try {
      await lsr.transferBatch(user1, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await lsr.approveBatchTransfer(user2, {from:user1});
    assert.equal(await lsr.transfers(user1), user2);
    await lsr.transferBatch(user1, {from:user2});
    await lsr.withdrawLimit(user2);
    // unregistered address should no longer have remaining stars
    assert.equal(await lsr.getRemainingStars(user1), 0);
  });

  it('withdrawing', async function() {
    assert.equal(await lsr.withdrawLimit(user2), 4);
    // only commitment participant can do this
    try {
      await lsr.withdraw({from:owner});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await lsr.withdraw({from:user2});
    assert.isTrue(await ships.isOwner(2048, user2));
    assert.equal((await lsr.batches(user2))[4], 1);
    await lsr.withdraw({from:user2});
    await lsr.withdraw({from:user2});
    await lsr.withdraw({from:user2});
    assert.equal((await lsr.batches(user2))[4], 4);
    assert.equal(await lsr.withdrawLimit(user2), 4);
    // can't withdraw over limit
    try {
      await lsr.withdraw({from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
  });
});
