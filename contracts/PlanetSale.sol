// default planet sale
// untested draft

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract PlanetSale is Ownable
{
  event PlanetSold(uint32 planet, uint value, uint32 remaining);
  event SaleEnded();

  function PlanetSale()
  {
    //
  }


  function end()
    public
    onlyOwner
  {
    SaleEnded();
    selfdestruct(owner);
  }
}
