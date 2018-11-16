//  base contract for the azimuth logic contract
//  encapsulates dependencies all constitutions need.

pragma solidity 0.4.24;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

import './ReadsShips.sol';
import './Polls.sol';

//  ConstitutionBase: upgradable constitution
//
//    This contract implements the upgrade logic for the Constitution.
//    Newer versions of the Constitution are expected to provide at least
//    the onUpgrade() function. If they don't, upgrading to them will fail.
//
//    Note that even though this contract doesn't specify any required
//    interface members aside from upgrade() and onUpgrade(), contracts
//    and clients may still rely on the presence of certain functions
//    provided by the Constitution proper. Keep this in mind when writing
//    updated versions of it.
//
contract ConstitutionBase is Ownable, ReadsShips
{
  event Upgraded(address to);

  //  polls: senate voting contract
  //
  Polls public polls;

  //  previousConstitution: address of the previous constitution this
  //                        instance expects to upgrade from, stored and
  //                        checked for to prevent unexpected upgrade paths
  //
  address public previousConstitution;

  constructor( address _previous,
               Ships _ships,
               Polls _polls )
    ReadsShips(_ships)
    internal
  {
    previousConstitution = _previous;
    polls = _polls;
  }

  //  onUpgrade(): called by previous constitution when upgrading
  //
  //    in future constitutions, this might perform more logic than
  //    just simple checks and verifications.
  //    when overriding this, make sure to call the original as well.
  //
  function onUpgrade()
    external
  {
    //  make sure this is the expected upgrade path,
    //  and that we have gotten the ownership we require
    //
    require( msg.sender == previousConstitution &&
             this == ships.owner() &&
             this == polls.owner() );
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
    //  transfer ownership of the data contracts
    //
    ships.transferOwnership(_new);
    polls.transferOwnership(_new);

    //  trigger upgrade logic on the target contract
    //
    _new.onUpgrade();

    //  emit event and destroy this contract
    //
    emit Upgraded(_new);
    selfdestruct(_new);
  }
}
