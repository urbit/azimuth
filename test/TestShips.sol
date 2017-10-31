pragma solidity ^0.4.15;

import "truffle/Assert.sol";

import '../contracts/Ships.sol';

contract TestShips
{
  Ships ships;
  address us;
  uint64 time;
  function beforeAll()
  {
    ships = new Ships();
    us = address(this);
    time = uint64(now);
  }

  function testGetOriginalParent()
  {
    // galaxies
    uint256 r0 = ships.getOriginalParent(0);
    Assert.equal(r0, 0,
      "0: not own parent");
    uint256 r255 = ships.getOriginalParent(255);
    Assert.equal(r255, 255,
      "255: not own parent");
    // stars
    uint256 r256 = ships.getOriginalParent(256);
    Assert.equal(r256, 0,
      "256: parent not 0");
    uint256 r65535 = ships.getOriginalParent(65535);
    Assert.equal(r65535, 255,
      "65535: parent not 255");
    // planets
    uint256 r1245952 = ships.getOriginalParent(1245952);
    Assert.equal(r1245952, 768,
      "1245952: parent not 0");
  }

  function testPilot()
  {
    Assert.equal(ships.hasPilot(0), false,
      "should not have pilot");
    ships.setPilot(0, us);
    Assert.equal(ships.hasPilot(0), true,
      "should have pilot");
    Assert.equal(ships.isPilot(0, us), true,
      "isPilot should agree");
  }

  function testPilotShiplist()
  {
    ships.setPilot(1, us);
    ships.setPilot(2, us);
    Assert.equal(ships.pilots(us, 0), uint256(0),
      "should list all ships");
    Assert.equal(ships.pilots(us, 1), uint256(1),
      "should list all ships");
    Assert.equal(ships.pilots(us, 2), uint256(2),
      "should list all ships");
    ships.setPilot(0, 0);
    Assert.equal(ships.pilots(us, 0), uint256(2),
      "should have neatly deleted ship");
    Assert.equal(ships.pilots(us, 1), uint256(1),
      "should have neatly deleted ship");
  }

  function testState()
  {
    // latent
    Assert.isTrue(ships.isState(0, Ships.State.Latent),
      "should be latent by default");
    // locked
    Assert.equal(ships.getLocked(0), uint256(0),
      "should be 0 by default");
    ships.setLocked(0, time);
    Assert.equal(ships.getLocked(0), uint256(time),
      "should be set to unlock time");
    // completed
    ships.setCompleted(0, time);
    Assert.equal(ships.getCompleted(0), uint256(time),
      "should be set to completion time");
    Assert.isTrue(ships.isState(0, Ships.State.Locked),
      "should be set to locked");
    // living
    ships.setLiving(257);
    Assert.equal(ships.getParent(257), uint256(1),
      "should have original parent");
    Assert.isTrue(ships.isState(257, Ships.State.Living),
      "should be set to living");
    ships.incrementChildren(0);
    Assert.equal(ships.getChildren(0), uint256(1),
      "should have incremented children");
  }

  function testEscape()
  {
    // escape should've been set to 65536 by setLiving
    Assert.isFalse(ships.isEscape(257, 0),
      "should have unset escape");
    ships.setEscape(257, 2);
    Assert.isTrue(ships.isEscape(257, 2),
      "should have set escape");
    ships.doEscape(257);
    Assert.isFalse(ships.isEscape(257, 2),
      "should have unset escape");
    Assert.equal(ships.getParent(257), uint256(2),
      "should have set parent");
  }

  function testKey()
  {
    var (key, rev) = ships.getKey(0);
    Assert.equal(key, bytes32(0),
      "should be 0 by default");
    Assert.equal(rev, uint256(0),
      "should be revision 0 by default");
    ships.setKey(0, 123);
    (key, rev) = ships.getKey(0);
    Assert.equal(key, bytes32(123),
      "should have set key");
    Assert.equal(rev, uint256(1),
      "should have incremented revision");
  }

  function testLauncher()
  {
    Assert.isFalse(ships.isLauncher(0, us),
      "should not be launcher by default");
    ships.setLauncher(0, us, true);
    Assert.isTrue(ships.isLauncher(0, us),
      "should have set launcher");
    ships.setLauncher(0, us, false);
    Assert.isFalse(ships.isLauncher(0, us),
      "should have unset launcher");
  }

  function testTransferrer()
  {
    ships.setTransferrer(0, us);
    Assert.isTrue(ships.isTransferrer(0, us),
      "should have set transferrer");
    ships.setTransferrer(0, 0);
    Assert.isTrue(ships.isTransferrer(0, 0),
      "should have unset transferrer");
  }

  function testShipData()
  {
    var (pilot, state, locked, completed, children, key, revision, parent,
         escape, transferrer) = ships.getShipData(0);
    Assert.equal(pilot, 0,
      "should have correct pilot");
    Assert.equal(state, uint256(1),
      "should have correct state");
    Assert.equal(locked, uint256(time),
      "should have correct locked");
    Assert.equal(completed, uint256(time),
      "should have correct completed");
    Assert.equal(children, uint256(1),
      "should have correct children");
    Assert.equal(key, bytes32(123),
      "should have correct key");
    Assert.equal(revision, uint256(1),
      "should have correct revision");
    Assert.equal(parent, uint256(0),
      "should have correct parent");
    Assert.equal(escape, uint256(0),
      "should have correct escape");
  }
}
