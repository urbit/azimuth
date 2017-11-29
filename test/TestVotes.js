const Votes = artifacts.require('../contracts/Votes.sol');

contract('Votes', function([owner, user]) {
  let votes;
  const concrProp = '0x11ce09f4ebe9d12f6e3864d21a1e7dde126f34eb';
  const abstrProp =
    '0xabcde00000000000000000000000000000000000000000000000000000000000';

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    votes = await Votes.new();
  });

  it('incrementing total voters', async function() {
    // non-owner can't do this.
    try {
      await votes.incrementTotalVoters({from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // increment total voters to three.
    assert.equal(await votes.totalVoters(), 0);
    for (var i = 0; i < 3; i++) {
      await votes.incrementTotalVoters();
    }
    assert.equal(await votes.totalVoters(), 3);
  });

  it('casting a minority concrete vote', async function() {
    // non-owner can't do this.
    try {
      await votes.castConcreteVote(0, concrProp, true, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // cast vote.
    await votes.castConcreteVote(0, concrProp, true);
    assert.isTrue(await votes.getVote(0, concrProp));
    assert.equal(await votes.concreteVoteCounts(owner, concrProp), 1);
    // can't change vote to be the same.
    try {
      await votes.castConcreteVote(0, concrProp, true);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // change vote.
    await votes.castConcreteVote(0, concrProp, false);
    assert.isFalse(await votes.getVote(0, concrProp));
    assert.equal(await votes.concreteVoteCounts(owner, concrProp), 0);
  });

  it('casting a majority concrete vote', async function() {
    let event = votes.ConcreteMajority({'constitution': concrProp});
    event.watch(function(err, res) {
      assert.isTrue(!err);
      assert.equal(res.args.constitution, concrProp);
      event.stopWatching();
    });
    await votes.castConcreteVote(0, concrProp, true);
    await votes.castConcreteVote(1, concrProp, true);
    assert.equal(await votes.concreteVoteCounts(owner, concrProp), 2);
  });

  it('casting a minority abstract vote', async function() {
    // non-owner can't do this.
    try {
      await votes.castAbstractVote(0, abstrProp, true, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // cast vote.
    await votes.castAbstractVote(0, abstrProp, true);
    assert.equal(await votes.abstractVoteCounts(abstrProp), 1);
    // can't change vote to be the same.
    try {
      await votes.castAbstractVote(0, abstrProp, true);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // change vote
    await votes.castAbstractVote(0, abstrProp, false);
    assert.equal(await votes.abstractVoteCounts(abstrProp), 0);
  });

  it('casting a majority abstract vote', async function() {
    await votes.castAbstractVote(0, abstrProp, true);
    await votes.castAbstractVote(1, abstrProp, true);
    assert.equal(await votes.abstractVoteCounts(abstrProp), 2);
    assert.equal(await votes.abstractMajorities(0), abstrProp);
  });
});
