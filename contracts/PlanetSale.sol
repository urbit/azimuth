// default planet sale
// untested draft

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Constitution.sol';

contract PlanetSale is Ownable
{
  event PlanetSold(uint32 planet, uint256 remaining);
  event SaleEnded();

  Constitution public constitution;
  uint32[] public available;
  uint256 public price; // in wei

  function PlanetSale(Constitution _constitution, uint32[] _planets,
                      uint256 _price)
  {
    constitution = _constitution;
    available = _planets;
    price = _price;
  }

  function getAvailable()
    external
    constant
    returns (uint32[] availablePlanets)
  {
    return available;
  }

  function getRemaining()
    external
    constant
    returns (uint256 remainingPlanets)
  {
    return available.length;
  }

  function buyAny()
    external
    payable
  {
    require(msg.value == price);
    require(available.length > 0);
    launch(available.length-1, msg.sender);
  }

  // specify the index to make the contract's work easier,
  // specify the planet to prevent buying an unintended planet.
  function buySpecific(uint256 _index, uint32 _planet)
    external
    payable
  {
    require(msg.value == price);
    require(_planet == available[_index]);
    launch(_index, msg.sender);
  }

  function launch(uint256 _index, address _target)
    internal
  {
    uint32 planet = available[_index];
    uint256 last = available.length - 1;
    available[_index] = available[last];
    available.length = last;
    constitution.launch(planet, _target);
    PlanetSold(planet, last);
    if (last == 0)
    {
      SaleEnded();
    }
  }

  function withdraw(address _target)
    external
    onlyOwner
  {
    _target.transfer(this.balance);
  }

  function close(address _target)
    external
    onlyOwner
  {
    SaleEnded();
    selfdestruct(_target);
  }

  function changeConstitution(Constitution _constitution)
    external
    onlyOwner
  {
    constitution = _constitution;
  }
}
