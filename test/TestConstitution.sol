pragma solidity ^0.4.15;

import "truffle/Assert.sol";

import '../contracts/Ships.sol';
import '../contracts/Votes.sol';
import '../contracts/Constitution.sol';

contract TestConstitution
{
  Ships ships;
  Votes votes;
  Constitution const;
  address us;
  uint64 time;

  function beforeAll()
  {
    ships = new Ships();
    votes = new Votes();
    const = new Constitution(ships, votes);
    ships.transferOwnership(const);
    votes.transferOwnership(const);
    us = address(this);
    time = uint64(now);
  }

  function testCreateGalaxy()
  {
    Assert.isFalse(ships.hasPilot(0),
      "should start out pilotless");
    const.createGalaxy(0, us, time, time);
    Assert.isTrue(ships.isState(0, Ships.State.Locked),
      "should have been locked");
    Assert.equal(ships.getLocked(0), uint256(time),
      "should have set lock-time");
    Assert.isTrue(ships.isPilot(0, us),
      "should have set pilot");
  }

  function testStart()
  {
    var (key, rev) = ships.getKey(0);
    Assert.equal(key, bytes32(0),
      "should start out keyless");
    Assert.equal(rev, uint256(0),
      "should start out unrevised");
    Assert.equal(votes.totalVoters(), uint256(0),
      "should not have any voters yet");
    const.start(0, 123);
    Assert.isTrue(ships.isState(0, Ships.State.Living),
      "should have been made living");
    (key, rev) = ships.getKey(0);
    Assert.equal(key, bytes32(123),
      "should have set key");
    Assert.equal(rev, uint256(1),
      "should have been revised");
    Assert.equal(votes.totalVoters(), uint256(1),
      "should have incremented total voters");
  }

  function testLaunch()
  {
    Assert.isFalse(ships.hasPilot(1024),
      "should start out pilotless");
    const.launch(1024, us, time);
    Assert.isTrue(ships.isPilot(1024, us),
      "should have set pilot");
    Assert.isTrue(ships.isState(1024, Ships.State.Locked),
      "should have been locked");
    Assert.equal(ships.getLocked(1024), uint256(time),
      "should have set lock-time");
  }

  function testLaunchRights()
  {
    Assert.isFalse(ships.isLauncher(1024, us),
      "should not be launcher by default");
    const.start(1024, 123);
    const.grantLaunchRights(1024, us);
    Assert.isTrue(ships.isLauncher(1024, us),
      "should have added launcher");
    const.revokeLaunchRights(1024, us);
    Assert.isFalse(ships.isLauncher(1024, us),
      "should have removed launcher");
  }

  function testTransferBy()
  {
    const.allowTransferBy(1024, us);
    Assert.isTrue(ships.isTransferrer(1024, us),
      "should have set transferrer");
  }

  function testRekey()
  {
    var (key, rev) = ships.getKey(1024);
    Assert.equal(key, bytes32(123),
      "should have set key");
    const.rekey(1024, 456);
    (key, rev) = ships.getKey(1024);
    Assert.equal(key, bytes32(456),
      "should have changed key");
  }

  function testEscape()
  {
    const.createGalaxy(1, us, time, time);
    const.start(1, 123);
    //
    const.escape(1024, 1);
    Assert.isTrue(ships.isEscape(1024, 1),
      "should have set escape");
    const.reject(1, 1024);
    Assert.isFalse(ships.isEscape(1024, 1),
      "should have unset escape");
    const.escape(1024, 1);
    const.adopt(1, 1024);
    Assert.isFalse(ships.isEscape(1024, 1),
      "should have unset escape after success");
    Assert.equal(ships.getParent(1024), uint256(1),
      "should have set parent");
  }

  function testTransfer()
  {
    Assert.isTrue(ships.isPilot(1024, us),
      "should have pilot set");
    const.transferShip(1024, 123, true);
    var (key, rev) = ships.getKey(1024);
    Assert.equal(key, bytes32(0),
      "should have reset key");
    Assert.isTrue(ships.isPilot(1024, 123),
      "should have changed pilot");
  }

  function testCastVote()
  {
    Assert.equal(votes.totalVoters(), uint256(2),
      "should have 2 active galaxies");
    const.castAbstractVote(0, bytes32(123), true);
    Assert.equal(votes.abstractVoteCounts(bytes32(123)), uint256(1),
      "should have cast vote");
    //
    Constitution other = new Constitution(ships, votes);
    const.castConcreteVote(0, other, true);
    const.castConcreteVote(1, other, true);
    Assert.equal(ships.owner(), other,
      "should have transfered ships ownership");
    Assert.equal(votes.owner(), other,
      "should have transfered votes ownership");
  }
}
