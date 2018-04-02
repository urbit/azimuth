//  base contract for the urbit constitution
//  encapsulates dependencies all constitutions need.

pragma solidity 0.4.21;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

import './Ships.sol';
import './Polls.sol';

//  ConstitutionBase: upgradable constitution
//
//    This contract implements the upgrade logic for the Constitution.
//    Newer versions of the Constitution are expected to provide at least
//    the upgraded() function. If they don't, upgrading to them will fail.
//
//    Note that even though this contract doesn't specify any required
//    interface members aside from upgrade() and upgraded(), contracts
//    and clients may still rely on the presence of certain functions
//    provided by the Constitution proper. Keep this in mind when writing
//    updated versions of it.
//
contract ConstitutionBase is Ownable
{
  event Upgraded(address to);

  //  ships: ship state data storage contract
  //  polls: senate voting contract
  //
  Ships public ships;
  Polls public polls;

  //  previousConstitution: address of the previous constitution this
  //                        instance expects to upgrade from, stored and
  //                        checked for to prevent unexpected upgrade paths
  //
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
    emit Upgraded(_new);
    selfdestruct(_new);
  }
}
