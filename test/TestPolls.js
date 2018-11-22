const Polls = artifacts.require('../contracts/Polls.sol');

const assertRevert = require('./helpers/assertRevert');
const increaseTime = require('./helpers/increaseTime');

const web3 = Polls.web3;

contract('Polls', function([owner, user]) {
  let polls, duration, cooldown;
  const concrProp = '0x11ce09f4ebe9d12f6e3864d21a1e7dde126f34eb';
  const concrProp2 = '0x22ce09f4ebe9d12f6e3864d21a1e7dde126f34eb';
  const abstrProp =
    '0xabcde00000000000000000000000000000000000000000000000000000000000';
  const abstrProp2 =
    '0xcdef100000000000000000000000000000000000000000000000000000000000';

  before('setting up for tests', async function() {
    polls = await Polls.new(432111, 432222);
    duration = 432000;
    cooldown = 7776000;
  });

  it('configuring polls', async function() {
    assert.equal(await polls.pollDuration(), 432111);
    assert.equal(await polls.pollCooldown(), 432222);
    assert.equal(await polls.totalVoters(), 0);
    await polls.reconfigure(duration, cooldown);
    for (var i = 0; i < 3; i++) {
      await polls.incrementTotalVoters();
    }
    assert.equal(await polls.pollDuration(), duration);
    assert.equal(await polls.pollCooldown(), cooldown);
    assert.equal(await polls.totalVoters(), 3);
    // can't set too high or too low
    await assertRevert(polls.reconfigure(431999, cooldown));
    await assertRevert(polls.reconfigure(7776001, cooldown));
    await assertRevert(polls.reconfigure(duration, 431999));
    await assertRevert(polls.reconfigure(duration, 7776001));
  });

  it('ecliptic poll start & majority', async function() {
    assert.isFalse(await polls.eclipticHasAchievedMajority(concrProp));
    // non-owner can't do this.
    await assertRevert(polls.startEclipticPoll(concrProp, {from:user}));
    await polls.startEclipticPoll(concrProp);
    let cPoll = await polls.eclipticPolls(concrProp);
    assert.notEqual(cPoll[0], 0);
    // non-owner can't do this.
    await assertRevert(polls.castEclipticVote(0, concrProp, true, {from:user}));
    // cast votes.
    // we use .call to check the result first, then actually transact.
    assert.isFalse(await polls.castEclipticVote.call(0, concrProp, true));
    await polls.castEclipticVote(0, concrProp, true);
    assert.isTrue(await polls.hasVotedOnEclipticPoll(0, concrProp));
    // can't vote twice.
    await assertRevert(polls.castEclipticVote(0, concrProp, true));
    assert.isFalse(await polls.castEclipticVote.call(1, concrProp, false));
    await polls.castEclipticVote(1, concrProp, false);
    assert.isTrue(await polls.castEclipticVote.call(2, concrProp, true));
    await polls.castEclipticVote(2, concrProp, true);
    assert.isTrue(await polls.eclipticHasAchievedMajority(concrProp));
    cPoll = await polls.eclipticPolls(concrProp);
    assert.equal(cPoll[1], 2);
    assert.equal(cPoll[2], 1);
    // can't vote on finished poll
    await assertRevert(polls.castEclipticVote(3, concrProp, true));
  });

  it('ecliptic poll minority & restart', async function() {
    // start poll and wait for it to time out
    await polls.startEclipticPoll(concrProp2);
    await polls.castEclipticVote(0, concrProp2, false);
    await increaseTime(duration);
    // can't vote on finished poll
    await assertRevert(polls.castEclipticVote(1, concrProp2, true));
    // can't recreate right away.
    await assertRevert(polls.startEclipticPoll(concrProp2));
    await increaseTime(cooldown + 5);
    // recreate poll.
    await polls.startEclipticPoll(concrProp2);
    let cPoll = await polls.eclipticPolls(concrProp2);
    assert.equal(cPoll[1], 0);
    assert.equal(cPoll[2], 0);
    assert.isFalse(await polls.hasVotedOnEclipticPoll(0, concrProp2));
    // test timeout majority
    await polls.castEclipticVote(0, concrProp2, true);
    assert.isTrue(await polls.hasVotedOnEclipticPoll(0, concrProp2));
    await increaseTime(duration + 5);
    assert.isTrue(await polls.updateEclipticPoll.call(concrProp2));
    await polls.updateEclipticPoll(concrProp2);
    assert.isTrue(await polls.eclipticHasAchievedMajority(concrProp2));
    // can't recreate once majority happened
    await assertRevert(polls.startEclipticPoll(concrProp2));
  });

  it('document poll start & majority', async function() {
    assert.isFalse(await polls.documentHasAchievedMajority(abstrProp));
    let mas = await polls.getDocumentMajorities();
    assert.equal(mas.length, 0);
    // non-owner can't do this.
    await assertRevert(polls.startDocumentPoll(abstrProp, {from:user}));
    await polls.startDocumentPoll(abstrProp);
    let aPoll = await polls.documentPolls(abstrProp);
    assert.notEqual(aPoll[0], 0);
    // non-owner can't do this.
    await assertRevert(polls.castDocumentVote(0, abstrProp, true, {from:user}));
    // cast votes.
    await polls.castDocumentVote(0, abstrProp, true);
    assert.isTrue(await polls.hasVotedOnDocumentPoll(0, abstrProp));
    // can't vote twice.
    await assertRevert(polls.castDocumentVote(0, abstrProp, true));
    await polls.castDocumentVote(1, abstrProp, false);
    await polls.castDocumentVote(2, abstrProp, true);
    assert.isTrue(await polls.documentHasAchievedMajority(abstrProp));
    mas = await polls.getDocumentMajorities();
    assert.equal(mas.length, 1);
    assert.equal(mas[0], abstrProp);
    aPoll = await polls.documentPolls(abstrProp);
    assert.equal(aPoll[1], 2);
    assert.equal(aPoll[2], 1);
    // can't vote on finished poll
    await assertRevert(polls.castDocumentVote(3, abstrProp, true));
    // can't recreate once majority happened.
    await assertRevert(polls.startDocumentPoll(abstrProp));
  });

  it('document poll minority & restart', async function() {
    // start poll and wait for it to time out
    await polls.startDocumentPoll(abstrProp2);
    await polls.castDocumentVote(0, abstrProp2, false);
    await increaseTime(duration);
    // can't vote on finished poll
    await assertRevert(polls.castDocumentVote(1, abstrProp2, true));
    // can't recreate right away.
    await assertRevert(polls.startDocumentPoll(abstrProp2));
    await increaseTime(cooldown + 5);
    // recreate poll.
    await polls.startDocumentPoll(abstrProp2);
    let aPoll = await polls.documentPolls(abstrProp2);
    assert.equal(aPoll[1], 0);
    assert.equal(aPoll[2], 0);
    assert.isFalse(await polls.hasVotedOnDocumentPoll(0, abstrProp2));
    // test timeout majority
    await polls.castDocumentVote(0, abstrProp2, true);
    assert.isTrue(await polls.hasVotedOnDocumentPoll(0, abstrProp2));
    await increaseTime(duration + 5);
    await polls.updateDocumentPoll(abstrProp2);
    assert.isTrue(await polls.documentHasAchievedMajority(abstrProp2));
  });

  it('strong minority case', async function() {
    // this test stretches the calculation in checkPollMajority to their limits
    let pox = await Polls.new(432111, 432222);
    for (let i = 0; i <= 255; i++) {
      await pox.incrementTotalVoters();
    }
    await pox.startDocumentPoll(abstrProp2);
    for (let i = 0; i <= 255; i++) {
      await pox.castDocumentVote(i, abstrProp2, false);
    }
  });
});
