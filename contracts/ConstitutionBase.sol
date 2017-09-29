// base contract for the urbit constitution
// encapsulates dependencies all constitutions need.

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Ships.sol';
import './Votes.sol';
import './Spark.sol';

contract ConstitutionBase is Ownable
{
  Ships public ships;
  Votes public votes;
  Spark public USP;

  function ConstitutionBase()
  {
    //
  }

  function upgrade(address _new)
    internal
  {
    ships.transferOwnership(_new);
    votes.transferOwnership(_new);
    USP.transferOwnership(_new);
    selfdestruct(_new);
  }
}
