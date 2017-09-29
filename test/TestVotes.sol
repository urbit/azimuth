pragma solidity ^0.4.15;

import "truffle/Assert.sol";

import '../contracts/Votes.sol';

contract TestVotes
{
  Votes votes;
  address us;
  address concrProp;
  bytes32 abstrProp;

  function beforeAll()
  {
    votes = new Votes();
    us = address(this);
    concrProp = address(0);
    abstrProp = bytes32(123);
  }

  function testIncrementTotalVoters()
  {
    Assert.equal(votes.totalVoters(), uint256(0),
      "totalVoters should start at 0");
    for (uint8 i = 0; i < 3; i++)
    {
      votes.incrementTotalVoters();
    }
    Assert.equal(votes.totalVoters(), uint256(3),
      "should have incremented three times");
  }

  function testMinorityConcreteVote()
  {
    Assert.isFalse(votes.castVote(0, concrProp, true),
      "should not be majority yet");
    Assert.isTrue(votes.getVote(0, concrProp),
      "should have set vote");
    Assert.equal(votes.concreteVoteCounts(us, concrProp), uint256(1),
      "should have added single vote");
    Assert.isFalse(votes.castVote(0, concrProp, false),
      "should not be majority yet");
    Assert.isFalse(votes.getVote(0, concrProp),
      "should have unset vote");
    Assert.equal(votes.concreteVoteCounts(us, concrProp), uint256(0),
      "should have subtracted vote");
  }

  function testMajorityConcreteVote()
  {
    Assert.isFalse(votes.castVote(0, concrProp, true),
      "should not be majority yet");
    Assert.isTrue(votes.castVote(1, concrProp, true),
      "should be majority");
    Assert.equal(votes.concreteVoteCounts(us, concrProp), uint256(2),
      "should have added votes");
  }

  function testMinorityAbstractVote()
  {
    votes.castVote(0, abstrProp, true);
    Assert.equal(votes.abstractVoteCounts(abstrProp), uint256(1),
      "should have added vote");
    votes.castVote(0, abstrProp, false);
    Assert.equal(votes.abstractVoteCounts(abstrProp), uint256(0),
      "should have subtracted vote");
  }

  function testMajorityAbstractVote()
  {
    votes.castVote(0, abstrProp, true);
    votes.castVote(1, abstrProp, true);
    Assert.equal(votes.abstractVoteCounts(abstrProp), uint256(2),
      "should have added votes");
    Assert.equal(votes.abstractMajorities(0), abstrProp,
      "should have added abstract majority");
  }
}
