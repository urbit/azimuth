// base contract for the urbit constitution
// encapsulates dependencies all constitutions need.

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Ships.sol';
import './Votes.sol';
import './Claims.sol';
import './Censures.sol';

contract ConstitutionBase is Ownable
{
  event Upgraded(address to);

  Ships public ships; // ships data storage
  Votes public votes; // votes data storage
  Claims public claims; // simple identity data storage
  Censures public censures; // simple reputation data storage

  function ConstitutionBase()
    internal
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
    claims.transferOwnership(_new);
    censures.transferOwnership(_new);
    Upgraded(_new);
    selfdestruct(_new);
  }
}
