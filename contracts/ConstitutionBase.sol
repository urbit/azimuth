// base contract for the urbit constitution
// encapsulates dependencies all constitutions need.

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Ships.sol';
import './Votes.sol';

contract ConstitutionBase is Ownable
{
  event Upgraded(address to);

  Ships public ships; // ships data storage
  Votes public votes; // votes data storage

  function ConstitutionBase()
    internal
  {
    //
  }

  //  upgrade(): transfer ownership of the constitution data to the new
  //             constitution contract, then self-destruct. 
  //
  //    Note: any eth that have somehow ended up in the contract are also 
  //          sent to the new constitution.
  //
  //    XX: old constitution should call an update hook function on the new.
  //
  function upgrade(address _new)
    internal
  {
    ships.transferOwnership(_new);
    votes.transferOwnership(_new);
    Upgraded(_new);
    selfdestruct(_new);
  }
}
