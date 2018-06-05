const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const CSR = artifacts.require('../contracts/ConditionalStarRelease.sol');

const assertRevert = require('./helpers/assertRevert');

contract('Conditional Star Release', function([owner, user1, user2, user3]) {
  let ships, polls, constit, csr,
      deadline1, deadline2, deadline3, condit2, rateUnit;

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
    deadline1 = Math.floor(Date.now() / 1000) + 1;
    deadline2 = deadline1 + 2;
    deadline3 = deadline2 + 2;
    condit2 = 123456789;
    rateUnit = 6;
    ships = await Ships.new();
    polls = await Polls.new(432000, 432000);
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
    csr = await CSR.new(ships.address, [0, condit2, "miss me", "too"],
                         [deadline1, deadline2, deadline3, deadline3+1000]);
    await constit.setSpawnProxy(0, csr.address);
    await constit.setTransferProxy(256, csr.address);
  });

  it('creation sanity check', async function() {
    // need as many deadlines as conditions
    await assertRevert(CSR.new(ships.address, [0, condit2], [deadline1]));
  });

  it('analyzing tranches', async function() {
    // first tranche has no condition, so automatically unlocked on-construct.
    assert.notEqual(await csr.timestamps(0), 0);
    // other tranches should not have timestamps yet.
    assert.equal(await csr.timestamps(3), 0);
    await csr.analyzeTranche(1);
    assert.equal(await csr.timestamps(1), 0);
    // fulfill condition for tranche 2
    await constit.startAbstractPoll(0, condit2);
    await constit.castAbstractVote(0, condit2, true);
    assert.isTrue(await polls.abstractMajorityMap(condit2));
    await csr.analyzeTranche(1, {from:user1});
    assert.notEqual(await csr.timestamps(1), 0);
    // can't analyzn twice
    await assertRevert(csr.analyzeTranche(1, {from:user1}));
    // miss deadline for tranche 3
    busywaitUntil(deadline3+1);
    await csr.analyzeTranche(2);
    assert.equal(await csr.timestamps(2), deadline3);
  });

  it('registering commitments', async function() {
    // only owner can do this
    await assertRevert(csr.register(user1, [1, 1, 5, 1], 1, rateUnit, {from:user1}));
    // need right amount of tranches
    await assertRevert(csr.register(user1, [1, 1, 5], 1, rateUnit));
    // need a sane rate
    await assertRevert(csr.register(user1, [1, 1, 5, 1], 0, rateUnit));
    assert.isTrue(await csr.verifyBalance(user1));
    await csr.register(user1, [1, 1, 5, 1], 1, rateUnit);
    await csr.register(user3, [1, 1, 5, 1], 1, rateUnit);
    assert.equal((await csr.commitments(user1))[0], 8);
    assert.isFalse(await csr.verifyBalance(user1));
    // can always withdraw at least one star
    assert.equal(await csr.withdrawLimit(user1), 1);
    let tranches = await csr.getTranches(user1);
    assert.equal(tranches[0], 1);
    assert.equal(tranches[1], 1);
    assert.equal(tranches[2], 5);
    assert.equal(tranches[3], 1);
    assert.equal(tranches.length, 4);
  });

  it('forfeiting early', async function() {
    // can't forfeit when deadline hasn't been missed
    await assertRevert(csr.forfeit(3, {from:user1}));
  });

  it('withdraw limit', async function() {
    await csr.register(owner, [1, 0, 5, 0], 2, rateUnit);
    assert.equal(await csr.withdrawLimit(user1), 1);
    busywaitUntil(deadline3+rateUnit);
    assert.equal(await csr.withdrawLimit(user1), 3);
    // unregistered address should not yet have a withdraw limit
    try {
      await csr.withdrawLimit(user2);
      assert.fail('should have thrown before');
    } catch(err) {
      assertInvalid(err);
    }
  });

  it('depositing stars', async function() {
    // only owner can do this
    await assertRevert(csr.deposit(user1, 256, {from:user1}));
    // can't deposit a live star
    await assertRevert(csr.deposit(user1, 2560));
    // deposit spawned star, as star owner
    await csr.deposit(user1, 256);
    // deposit unspawned stars, as galaxy owner
    for (var s = 2; s < 9; s++) {
      await csr.deposit(user1, s*256);
    }
    assert.equal((await csr.getRemainingStars(user1)).length, 8);
    assert.equal((await csr.getRemainingStars(user1))[7], 2048);
    assert.isTrue(await ships.isOwner(256, csr.address));
    assert.isTrue(await csr.verifyBalance(user1));
    // can't deposit too many
    await assertRevert(csr.deposit(user1, 2304));
  });

  it('withdrawing', async function() {
    assert.equal(await csr.withdrawLimit(user1), 3);
    // only commitment participant can do this
    await assertRevert(csr.withdraw({from:owner}));
    await csr.withdraw({from:user1});
    assert.isTrue(await ships.isOwner(2048, user1));
    assert.equal((await csr.commitments(user1))[3], 1);
    // can't withdraw over limit
    await assertRevert(csr.withdraw());
    assert.equal(await csr.withdrawLimit(user1), 3);
    await csr.withdraw({from:user1});
    await csr.withdraw({from:user1});
    assert.equal((await csr.commitments(user1))[3], 3);
  });

  it('transferring commitment', async function() {
    assert.equal(await csr.transfers(user1), 0);
    // can't transfer to other participant
    await assertRevert(csr.approveCommitmentTransfer(user3, {from:user1}));
    // can't transfer without permission
    await assertRevert(csr.transferCommitment(user1, {from:user2}));
    await csr.approveCommitmentTransfer(user2, {from:user1});
    assert.equal(await csr.transfers(user1), user2);
    await csr.transferCommitment(user1, {from:user2});
    await csr.withdrawLimit(user2);
    // unregistered address should no longer have tranches, etc
    let tranches = await csr.getTranches(user1);
    assert.equal(tranches.length, 0);
  });

  it('forfeiting and withdrawing', async function() {
    await csr.forfeit(2, {from:user2});
    // can't forfeit twice
    await assertRevert(csr.forfeit(2, {from:user2}));
    let com = await csr.commitments(user2);
    assert.isTrue(com[4]);
    assert.equal(com[5], com[0] - com[3]);
    assert.equal(com[5], 5);
    busywait(rateUnit);
    // can't withdraw because of forfeit
    await assertRevert(csr.withdraw({from:user2}));
    // only owner can still withdraw
    await assertRevert(csr.withdrawForfeited(user2, owner, {from:user2}));
    for (var i = 0; i < 5; i++) {
      await csr.withdrawForfeited(user2, owner);
    }
    assert.isTrue(await ships.isOwner(256, owner));
  });
});
