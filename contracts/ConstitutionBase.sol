// base contract for the urbit constitution
// encapsulates dependencies all constitutions need.

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Ships.sol';
import './Polls.sol';

contract ConstitutionBase is Ownable
{
  event Upgraded(address to);

  Ships public ships; // ships data storage
  Polls public polls; // polls data storage

  address public previousConstitution;

  function ConstitutionBase(address _previous, Ships _ships, Polls _polls)
    internal
  {
    previousConstitution = _previous;
    ships = _ships;
    polls = _polls;
  }

  //  upgraded(): called by previous constitution when upgrading
  //
  function upgraded()
    external
  {
    require(msg.sender == previousConstitution);
  }

  //  upgrade(): transfer ownership of the constitution data to the new
  //             constitution contract, notify it, then self-destruct.
  //
  //    Note: any eth that have somehow ended up in the contract are also
  //          sent to the new constitution.
  //
  function upgrade(ConstitutionBase _new)
    internal
  {
    ships.transferOwnership(_new);
    polls.transferOwnership(_new);
    _new.upgraded();
    Upgraded(_new);
    selfdestruct(_new);
  }
}
