pragma solidity ^0.4.15;

import "truffle/Assert.sol";

import '../contracts/PlanetSale.sol';

contract TestPlanetSale
{
  uint public initialBalance = 1 ether;

  Ships ships;
  Constitution const;
  PlanetSale sale;

  function beforeAll()
  {
    ships = new Ships();
    Votes votes = new Votes();
    Spark USP = new Spark();
    const = new Constitution(ships, votes, USP);
    ships.transferOwnership(const);
    votes.transferOwnership(const);
    USP.transferOwnership(const);
    const.createGalaxy(0, this, 0);
    const.start(0, 123);
    const.liquidateStar(256);
    USP.approve(const, 1000000000000000000);
    const.claimStar(256);
    const.start(256, 123);
    uint32[] memory planets = new uint32[](4);
    planets[0] = 1048832;
    planets[1] = 1114368;
    planets[2] = 1179904;
    planets[3] = 1245440;
    sale = new PlanetSale(const, planets, 10);
    const.grantLaunchRights(256, sale);
  }

  function testInitialization()
  {
    Assert.equal(sale.getRemaining(), uint256(4),
      "should have 4 planets for sale");
    Assert.equal(sale.available(0), uint256(1048832),
      "should have starting planets for sale");
    Assert.equal(sale.available(1), uint256(1114368),
      "should have starting planets for sale");
    Assert.equal(sale.available(2), uint256(1179904),
      "should have starting planets for sale");
    Assert.equal(sale.available(3), uint256(1245440),
      "should have starting planets for sale");
  }

  function testBuyAnyPlanet()
  {
    sale.buyAny.value(10)();
    Assert.equal(sale.getRemaining(), uint256(3),
      "should have sold a planet");
    Assert.equal(sale.available(0), uint256(1048832),
      "should have sold last planet in array");
    Assert.equal(sale.available(1), uint256(1114368),
      "should have sold last planet in array");
    Assert.equal(sale.available(2), uint256(1179904),
      "should have sold last planet in array");
  }

  function testBuySpecificPlanet()
  {
    sale.buySpecific.value(10)(0, 1048832);
    Assert.equal(sale.getRemaining(), uint256(3),
      "should have sold a planet");
    Assert.equal(sale.available(0), uint256(1245440),
      "should have sold first planet in array");
    Assert.equal(sale.available(1), uint256(1114368),
      "should have sold first planet in array");
    Assert.equal(sale.available(3), uint256(1245440),
      "should have starting planets for sale");
  }
}
