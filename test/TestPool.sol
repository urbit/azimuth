pragma solidity ^0.4.15;

import "truffle/Assert.sol";

import '../contracts/Pool.sol';

contract TestPool
{
  Ships ships;
  Constitution const;
  Pool pool;

  function beforeAll()
  {
    ships = new Ships();
    Votes v = new Votes();
    const = new Constitution(ships, v);
    ships.transferOwnership(const);
    v.transferOwnership(const);
    const.createGalaxy(0, this, 0, 0);
    const.start(0, 123);
    pool = new Pool(ships);
    const.grantLaunchRights(0, pool);
  }

  function testDeposit()
  {
    pool.deposit(256);
    Assert.isTrue(ships.isPilot(256, address(pool)),
      "should have been launched to pool");
    Assert.equal(pool.balanceOf(this), pool.oneStar(),
      "should have granted a token");
  }

  function testWithdraw()
  {
    pool.approve(address(pool), pool.oneStar());
    Assert.equal(pool.allowance(this, address(pool)), pool.oneStar(),
      "should have given allowance");
    pool.withdraw(256);
    Assert.isTrue(ships.isPilot(256, this),
      "should have transfered star");
    Assert.equal(pool.balanceOf(this), uint256(0),
      "should have taken a token");
  }
}
