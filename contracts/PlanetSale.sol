//  bare-bones sample planet sale contract

pragma solidity 0.4.24;

import './Ecliptic.sol';

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

//  PlanetSale: a practically stateless point sale contract
//
//    This contract facilitates the sale of points (most commonly planets).
//    Instead of "depositing" points into this contract, points are
//    available for sale when this contract is able to spawn them.
//    This is the case when the point is inactive and its prefix has
//    allowed this contract to spawn for it.
//
//    The contract owner can determine the price per point, withdraw funds
//    that have been sent to this contract, and shut down the contract
//    to prevent further sales.
//
//    This contract is intended to be deployed by star owners that want
//    to sell their planets on-chain.
//
contract PlanetSale is Ownable
{
  //  PlanetSold: _planet has been sold
  //
  event PlanetSold(uint32 indexed prefix, uint32 indexed planet);

  //  azimuth: points state data store
  //
  Azimuth public azimuth;

  //  price: ether per planet, in wei
  //
  uint256 public price;

  //  constructor(): configure the points data store and initial sale price
  //
  constructor(Azimuth _azimuth, uint256 _price)
    public
  {
    require(0 < _price);
    azimuth = _azimuth;
    setPrice(_price);
  }

  //
  //  Buyer operations
  //

    //  available(): returns true if the _planet is available for purchase
    //
    function available(uint32 _planet)
      public
      view
      returns (bool result)
    {
      uint16 prefix = azimuth.getPrefix(_planet);

      return ( //  planet must not have an owner yet
               //
               azimuth.isOwner(_planet, 0x0) &&
               //
               //  this contract must be allowed to spawn for the prefix
               //
               azimuth.isSpawnProxy(prefix, this) &&
               //
               //  prefix must be linked
               //
               azimuth.hasBeenLinked(prefix) );
    }

    //  purchase(): pay the :price, acquire ownership of the _planet
    //
    //    discovery of available planets can be done off-chain
    //
    function purchase(uint32 _planet)
      external
      payable
    {
      require( //  caller must pay exactly the price of a planet
               //
               (msg.value == price) &&
               //
               //  the planet must be available for purchase
               //
               available(_planet) );

      //  spawn the planet to us, then immediately transfer to the caller
      //
      //    spawning to the caller would give the point's prefix's owner
      //    a window of opportunity to cancel the transfer
      //
      Ecliptic ecliptic = Ecliptic(azimuth.owner());
      ecliptic.spawn(_planet, this);
      ecliptic.transferPoint(_planet, msg.sender, false);
      emit PlanetSold(azimuth.getPrefix(_planet), _planet);
    }

  //
  //  Seller operations
  //

    //  setPrice(): configure the price in wei per planet
    //
    function setPrice(uint256 _price)
      public
      onlyOwner
    {
      require(0 < _price);
      price = _price;
    }

    //  withdraw(): withdraw ether funds held by this contract to _target
    //
    function withdraw(address _target)
      external
      onlyOwner
    {
      require(0x0 != _target);
      _target.transfer(address(this).balance);
    }

    //  close(): end the sale by destroying this contract and transferring
    //           remaining funds to _target
    //
    function close(address _target)
      external
      onlyOwner
    {
      require(0x0 != _target);
      selfdestruct(_target);
    }
}
