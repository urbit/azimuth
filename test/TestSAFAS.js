const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const SAFAS = artifacts.require('../contracts/SAFAS.sol');

contract('SAFAS', function([owner, user1, user2]) {
  let ships, polls, constit, safas,
      deadline1, deadline2, deadline3, condit2, rateUnit;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
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
    deadline1 = Math.floor(Date.now() / 1000) + 1;
    deadline2 = deadline1 + 2;
    deadline3 = deadline2 + 2;
    condit2 = 123456789;
    rateUnit = 6;
    ships = await Ships.new();
    polls = await Polls.new(60, 0);
    constit = await Constitution.new(0, ships.address, polls.address);
    await ships.transferOwnership(constit.address);
    await polls.transferOwnership(constit.address);
    await constit.createGalaxy(0, owner);
    await constit.configureKeys(0, 1, 2);
    safas = await SAFAS.new(ships.address, [0, condit2, "miss me", "too"],
                            [deadline1, deadline2, deadline3, deadline3+1000]);
    await constit.setSpawnProxy(0, safas.address);
  });

  it('analyzing tranches', async function() {
    // first tranche has no condition, so automatically unlocked on-construct.
    assert.notEqual(await safas.timestamps(0), 0);
    // other tranches should not have timestamps yet.
    assert.equal(await safas.timestamps(3), 0);
    await safas.analyzeTranche(1);
    assert.equal(await safas.timestamps(1), 0);
    // fulfill condition for tranche 2
    await constit.startAbstractPoll(0, condit2);
    await constit.castAbstractVote(0, condit2, true);
    assert.isTrue(await polls.abstractMajorityMap(condit2));
    await safas.analyzeTranche(1, {from:user1});
    assert.notEqual(await safas.timestamps(1), 0);
    // miss deadline for tranche 3
    busywaitUntil(deadline3+1);
    await safas.analyzeTranche(2);
    assert.equal(await safas.timestamps(2), deadline3);
  });

  it('registering commitments', async function() {
    // only owner can do this
    try {
      await safas.register(user1, [1, 1, 5, 1], 1, rateUnit, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // need right amount of tranches
    try {
      await safas.register(user1, [1, 1, 5], 1, rateUnit);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    assert.isTrue(await safas.verifyBalance(user1));
    await safas.register(user1, [1, 1, 5, 1], 1, rateUnit);
    assert.equal((await safas.commitments(user1))[0], 8);
    assert.isFalse(await safas.verifyBalance(user1));
    // can always withdraw at least one star
    assert.equal(await safas.withdrawLimit(user1), 1);
  });

  it('withdraw limit', async function() {
    await safas.register(owner, [1, 0, 5, 0], 2, rateUnit);
    assert.equal(await safas.withdrawLimit(user1), 1);
    busywaitUntil(deadline3+rateUnit);
    assert.equal(await safas.withdrawLimit(user1), 3);
  });

  it('depositing stars', async function() {
    // only owner can do this
    try {
      await safas.deposit(user1, 256, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    for (var s = 1; s < 9; s++) {
      await safas.deposit(user1, s*256);
    }
    assert.equal((await safas.getRemainingStars(user1)).length, 8);
    assert.equal((await safas.getRemainingStars(user1))[7], 2048);
    assert.isTrue(await ships.isOwner(256, safas.address));
    assert.isTrue(await safas.verifyBalance(user1));
  });

  it('withdrawing', async function() {
    assert.equal(await safas.withdrawLimit(user1), 3);
    // only commitment participant can do this
    try {
      await safas.withdraw(user1);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await safas.withdraw(user1, {from:user1});
    assert.isTrue(await ships.isOwner(2048, user1));
    assert.equal((await safas.commitments(user1))[3], 1);
    // can't withdraw over limit
    try {
      await safas.withdraw(user1);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    assert.equal(await safas.withdrawLimit(user1), 3);
    await safas.withdraw(user1, {from:user1});
    await safas.withdraw(user1, {from:user1});
    assert.equal((await safas.commitments(user1))[3], 3);
  });

  it('forfeiting and withdrawing', async function() {
    await safas.forfeit(2, {from:user1});
    let com = await safas.commitments(user1);
    assert.isTrue(com[4]);
    assert.equal(com[5], com[0] - com[3]);
    assert.equal(com[5], 5);
    busywait(rateUnit);
    // can't withdraw because of forfeit
    try {
      await safas.withdraw(user1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    for (var i = 0; i < 5; i++) {
      await safas.withdrawForfeited(user1, owner);
    }
    assert.isTrue(await ships.isOwner(256, owner));
  })
});
