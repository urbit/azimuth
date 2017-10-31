// default planet sale
// draft

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

  // buys a planet from the top of the stack.
  function buyAny()
    external
    payable
  {
    require(msg.value == price);
    require(available.length > 0);
    launch(available.length-1, msg.sender);
  }

  // buys a specific planet from the pile.
  // we require the index to make the contract's work easier,
  // we require the planet to prevent race-conditions resulting in an unintended
  // purchase.
  function buySpecific(uint256 _index, uint32 _planet)
    external
    payable
  {
    require(msg.value == price);
    require(_planet == available[_index]);
    launch(_index, msg.sender);
  }

  // send the planet at the given index to the target address.
  function launch(uint256 _index, address _target)
    internal
  {
    uint32 planet = available[_index];
    uint256 last = available.length - 1;
    // replace the new "gap" with the last planet in the list, and then shorten
    // the list by one.
    available[_index] = available[last];
    available.length = last;
    constitution.launch(planet, _target, 0);
    PlanetSold(planet, last);
    if (last == 0)
    {
      SaleEnded();
    }
  }

  // withdraw the funds sent to this contract.
  function withdraw(address _target)
    external
    onlyOwner
  {
    _target.transfer(this.balance);
  }

  // close the sale and send any remaining funds to the target address.
  function close(address _target)
    external
    onlyOwner
  {
    SaleEnded();
    selfdestruct(_target);
  }

  // this may be needed when a constitution upgrade has happened.
  function changeConstitution(Constitution _constitution)
    external
    onlyOwner
  {
    constitution = _constitution;
  }
}
