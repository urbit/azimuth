const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Ecliptic = artifacts.require('../contracts/Ecliptic.sol');
const CSR = artifacts.require('../contracts/ConditionalStarRelease.sol');

const assertRevert = require('./helpers/assertRevert');
const increaseTime = require('./helpers/increaseTime');

contract('Conditional Star Release', function([owner, user1, user2, user3]) {
  let azimuth, azimuth2, polls, eclipt, eclipt2, csr, csr2,
      deadline1, deadline2, deadline3, condit2, rateUnit,
      deadlineStep, escapeHatchTime, escapeHatchDate;

  function assertInvalid(error) {
    assert.isAbove(error.message.search('invalid opcode'), -1, 'Invalid opcode must be returned, but got ' + error);
  }

  function getChainTime() {
    return new Promise((resolve, reject) => {
      web3.currentProvider.sendAsync({
        jsonrpc: '2.0',
        method: 'eth_getBlockByNumber',
        params: ['latest', false],
        id: 'csr-getting-time',
      }, (err, res) => {
        if (err) return reject(err);
        return resolve(res.result.timestamp);
      });
    });
  };

  before('setting up for tests', async function() {
    deadlineStep = 100;
    condit2 = 123456789;
    rateUnit = deadlineStep * 10;
    azimuth = await Azimuth.new();
    azimuth2 = await Azimuth.new();
    polls = await Polls.new(432000, 432000);
    claims = await Claims.new(azimuth.address);
    eclipt = await Ecliptic.new(0x1, azimuth.address, polls.address,
                                     claims.address);
    eclipt2 = await Ecliptic.new(0x0, azimuth2.address,
                                      polls.address, claims.address)
    await azimuth.transferOwnership(eclipt.address);
    await azimuth2.transferOwnership(eclipt2.address);
    await polls.transferOwnership(eclipt.address);
    await eclipt.createGalaxy(0, owner);
    await eclipt.configureKeys(0, 1, 2, 1, false);
    await eclipt.spawn(256, owner);
    await eclipt.spawn(2560, owner);
    await eclipt.configureKeys(2560, 1, 2, 1, false);
    deadline1 = web3.toDecimal(await getChainTime()) + 10;
    deadline2 = deadline1 + deadlineStep;
    deadline3 = deadline2 + deadlineStep;
    deadline4 = deadline3 + deadlineStep;
    escapeHatchTime = deadlineStep * 100;
    escapeHatchDate = web3.toDecimal(await getChainTime()) + escapeHatchTime;
    csr = await CSR.new( azimuth.address, [0, condit2, "miss me", "too"],
                         [0, 0, 0, 0],
                         [deadline1, deadline2, deadline3, deadline4],
                         escapeHatchDate );
    csr2 = await CSR.new( azimuth2.address, [0, condit2, "miss me", "too"],
                          [0, 0, 0, 0],
                          [deadline1, deadline2, deadline3, deadline4],
                          escapeHatchDate );
    await eclipt.setSpawnProxy(0, csr.address);
    await eclipt.setTransferProxy(256, csr.address);
  });

  it('creation sanity check', async function() {
    // need as many deadlines as conditions
    await assertRevert(CSR.new(azimuth.address, [0, condit2], [0, 0], [0], 1));
    await assertRevert(CSR.new(azimuth.address, [0, condit2], [0], [0, 0], 1));
    // can't have too many conditions
    let many = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    await assertRevert(CSR.new(azimuth.address, many, many, many, 1));
    // can't have unfair escape hatch
    let few = [2, 2, 2];
    await assertRevert(CSR.new(azimuth.address, few, few, few, 1));
  });

  it('analyzing conditions', async function() {
    // first condition is zero, so might get automatically unlocked on-construct
    assert.notEqual(await csr.timestamps(0), 0);
    assert.equal(await csr2.timestamps(0), 0);
    // other conditions should not have timestamps yet.
    assert.equal(await csr.timestamps(3), 0);
    await csr.analyzeCondition(1);
    assert.equal(await csr.timestamps(1), 0);
    // fulfill condition 2
    await eclipt.startDocumentPoll(0, condit2);
    await eclipt.castDocumentVote(0, condit2, true);
    assert.isTrue(await polls.documentHasAchievedMajority(condit2));
    await csr.analyzeCondition(1, {from:user1});
    assert.notEqual(await csr.timestamps(1), 0);
    // can't analyze twice
    await assertRevert(csr.analyzeCondition(1, {from:user1}));
    // miss deadline for condition 3
    await increaseTime((deadlineStep * 2) + 10);
    await csr.analyzeCondition(2);
    assert.equal(await csr.timestamps(2), deadline3);
    // verify contract state getters work
    let [conds, lives, deads, times] = await csr.getConditionsState();
    assert.equal(conds[3],
      // "too"
      "0x746f6f0000000000000000000000000000000000000000000000000000000000");
    assert.equal(lives[3], 0);
    assert.equal(deads[3], deadline4);
    assert.equal(times[2], deadline3);
    assert.equal(times[3], 0);
  });

  it('registering commitments', async function() {
    // only owner can do this
    await assertRevert(csr.register(user1, [4, 1, 2, 1], 1, rateUnit, {from:user1}));
    // need right amount of conditions
    await assertRevert(csr.register(user1, [4, 1, 2], 1, rateUnit));
    // need a sane rate
    await assertRevert(csr.register(user1, [4, 1, 2, 1], 0, rateUnit));
    // must contain stars
    await assertRevert(csr.register(user1, [0, 0, 0, 0], 1, rateUnit));
    assert.isTrue(await csr.verifyBalance(user1));
    await csr.register(user1, [4, 1, 2, 1], 1, rateUnit);
    await csr.register(user3, [0, 1, 2, 1], 1, rateUnit);
    // can't register twice
    await assertRevert(csr.register(user3, [4, 1, 2, 1], 1, rateUnit));
    assert.equal((await csr.commitments(user1))[2], 8);
    assert.isFalse(await csr.verifyBalance(user1));
    // can always withdraw at least one star from the first batch that has stars
    assert.equal(await csr.withdrawLimit(user1, 0), 1);
    assert.equal(await csr.withdrawLimit(user1, 1), 0);
    assert.equal(await csr.withdrawLimit(user3, 0), 0);
    assert.equal(await csr.withdrawLimit(user3, 1), 1);
    let batches = await csr.getBatches(user1);
    assert.equal(batches[0], 4);
    assert.equal(batches[1], 1);
    assert.equal(batches[2], 2);
    assert.equal(await csr.getBatch(user1, 2), 2);
    assert.equal(batches[3], 1);
    assert.equal(batches.length, 4);
  });

  it('forfeiting early', async function() {
    // can't forfeit when deadline hasn't been missed
    await assertRevert(csr.forfeit(3, {from:user1}));
  });

  it('withdraw limit', async function() {
    assert.equal(await csr.withdrawLimit(user1, 0), 1);
    assert.equal(await csr.withdrawLimit(user1, 3), 0);
    await increaseTime(rateUnit*2);
    assert.equal(await csr.withdrawLimit(user1, 0), 2);
    // unregistered address should not yet have a withdraw limit
    assert.equal(await csr.withdrawLimit(user2, 0), 0);
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
    assert.isTrue(await azimuth.isOwner(256, csr.address));
    assert.isTrue(await csr.verifyBalance(user1));
    // can't deposit too many
    await assertRevert(csr.deposit(user1, 2304));
  });

  it('withdrawing', async function() {
    await increaseTime(rateUnit);
    assert.equal(await csr.withdrawLimit(user1, 0), 3);
    // only commitment participant can do this
    await assertRevert(csr.withdrawToSelf(0, {from:owner}));
    await csr.withdrawToSelf(0, {from:user1});
    assert.isTrue(await azimuth.isOwner(2048, user1));
    assert.equal((await csr.getWithdrawn(user1))[0], 1);
    // can't withdraw over limit
    assert.equal(await csr.withdrawLimit(user1, 0), 3);
    await csr.withdraw(0, user1, {from:user1});
    assert.isTrue(await azimuth.isOwner(1792, user1));
    await csr.withdrawToSelf(0, {from:user1});
    assert.equal(await csr.getWithdrawnFromBatch(user1, 0), 3);
    await assertRevert(csr.withdrawToSelf(0, {from:user1}));
  });

  it('transferring commitment', async function() {
    assert.equal((await csr.commitments(user1))[1], 0);
    // can't transfer to other participant
    await assertRevert(csr.approveCommitmentTransfer(user3, {from:user1}));
    // can't transfer without permission
    await assertRevert(csr.transferCommitment(user1, {from:user2}));
    await csr.approveCommitmentTransfer(user2, {from:user1});
    await csr.approveCommitmentTransfer(user2, {from:user3});
    assert.equal((await csr.commitments(user1))[1], user2);
    await csr.transferCommitment(user1, {from:user2});
    assert.notEqual(await csr.withdrawLimit(user2, 0), 0);
    // can't if we became a participant in the mean time
    await assertRevert(csr.transferCommitment(user3, {from:user2}));
    // unregistered address should no longer have batches, etc
    let batches = await csr.getBatches(user1);
    assert.equal(batches.length, 0);
  });

  it('forfeiting and withdrawing', async function() {
    // owner can't withdraw if not forfeited
    assert.isFalse((await csr.getForfeited(user2))[2]);
    await assertRevert(csr.withdrawForfeited(user2, 2, owner));
    // can't forfeit if no commitment
    await assertRevert(csr.forfeit(2, {from:user1}));
    await csr.forfeit(2, {from:user2});
    assert.isTrue(await csr.hasForfeitedBatch(user2, 2));
    // can't forfeit twice
    await assertRevert(csr.forfeit(2, {from:user2}));
    // can't withdraw because of forfeit
    await assertRevert(csr.withdrawToSelf(2, {from:user2}));
    // can't forfeit when we've withdrawn
    await csr.analyzeCondition(3);
    assert.equal(await csr.timestamps(3), deadline4);
    await csr.withdrawToSelf(3, {from:user2});
    await assertRevert(csr.forfeit(3, {from:user2}));
    // only owner can still withdraw
    await assertRevert(csr.withdrawForfeited(user2, 2, user2, {from:user2}));
    await csr.withdrawForfeited(user2, 2, owner);
    assert.isTrue(await azimuth.isOwner(1024, owner));
  });

  it('escape hatch', async function() {
    await assertRevert(csr.withdrawOverdue(user2, owner));
    await increaseTime(escapeHatchTime);
    await csr.withdrawOverdue(user2, owner);
    assert.isTrue(await azimuth.isOwner(2560, owner));
  });
});
