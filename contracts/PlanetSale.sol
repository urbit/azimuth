//  bare-bones sample planet sale contract

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Constitution.sol';

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

  //  PlanetSale(): configure the ships data store and initial sale price
  //
  function PlanetSale(Ships _ships, uint256 _price)
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
      PlanetSold(_planet);
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
      _target.transfer(this.balance);
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
