// base contract for the urbit constitution
// encapsulates dependencies all constitutions need.

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Ships.sol';
import './Votes.sol';

contract ConstitutionBase is Ownable
{
  Ships public ships; // ships data storage
  Votes public votes; // votes data storage

  function ConstitutionBase()
  {
    //
  }

  // transfer ownership of the data and token contracts to the new
  // constitution, then self-destruct. any eth that have somehow ended up in
  // the contract are also sent to the new constitution.
  function upgrade(address _new)
    internal
  {
    ships.transferOwnership(_new);
    votes.transferOwnership(_new);
    selfdestruct(_new);
  }
}
