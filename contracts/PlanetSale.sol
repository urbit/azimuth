//  bare-bones sample planet sale contract

pragma solidity 0.4.24;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Constitution.sol';

//  PlanetSale: a practically stateless ship sale contract
//
//    This contract facilitates the sale of ships (most commonly planets).
//    Instead of "depositing" ships into this contract, ships are
//    available for sale when this contract is able to spawn them.
//    This is the case when the ship is inactive and its prefix has
//    allowed this contract to spawn for it.
//
//    The contract owner can determine the price per ship, withdraw funds
//    that have been sent to this contract, and shut down the contract
//    to prevent further sales.
//
//    This contract is intended to be deployed by star owners that want
//    to sell that planets on-chain.
//
contract PlanetSale is Ownable
{
  //  PlanetSold: _planet has been sold
  //
  event PlanetSold(uint32 planet);

  //  ships: ships state data store
  //
  Ships public ships;

  //  price: ether per planet, in wei
  //
  uint256 public price;

  //  constructor(): configure the ships data store and initial sale price
  //
  constructor(Ships _ships, uint256 _price)
    public
  {
    ships = _ships;
    price = _price;
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
      uint16 prefix = ships.getPrefix(_planet);

      return ( //  planet must not be active yet
               //
               !ships.isActive(_planet) &&
               //
               //  this contract must be allowed to spawn for the prefix
               //
               ships.isSpawnProxy(prefix, this) &&
               //
               //  prefix must be live
               //
               ships.hasBeenBooted(prefix) );
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

      //  spawn the planet to its new owner
      //
      Constitution(ships.owner()).spawn(_planet, msg.sender);
      emit PlanetSold(_planet);
    }

  //
  //  Seller operations
  //

    //  setPrice(): configure the price in wei per planet
    //
    function setPrice(uint256 _price)
      external
      onlyOwner
    {
      price = _price;
    }

    //  withdraw(): withdraw ether funds held by this contract to _target
    //
    function withdraw(address _target)
      external
      onlyOwner
    {
      _target.transfer(address(this).balance);
    }

    //  close(): end the sale by destroying this contract and transfering
    //           remaining funds to _target
    //
    function close(address _target)
      external
      onlyOwner
    {
      selfdestruct(_target);
    }
}
