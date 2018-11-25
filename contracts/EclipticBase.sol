//  base contract for the azimuth logic contract
//  encapsulates dependencies all ecliptics need.

pragma solidity 0.4.24;

import './ReadsAzimuth.sol';
import './Polls.sol';

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

//  EclipticBase: upgradable ecliptic
//
//    This contract implements the upgrade logic for the Ecliptic.
//    Newer versions of the Ecliptic are expected to provide at least
//    the onUpgrade() function. If they don't, upgrading to them will fail.
//
//    Note that even though this contract doesn't specify any required
//    interface members aside from upgrade() and onUpgrade(), contracts
//    and clients may still rely on the presence of certain functions
//    provided by the Ecliptic proper. Keep this in mind when writing
//    new versions of it.
//
contract EclipticBase is Ownable, ReadsAzimuth
{
  event Upgraded(address to);

  //  polls: senate voting contract
  //
  Polls public polls;

  //  previousEcliptic: address of the previous ecliptic this
  //                    instance expects to upgrade from, stored and
  //                    checked for to prevent unexpected upgrade paths
  //
  address public previousEcliptic;

  constructor( address _previous,
               Azimuth _azimuth,
               Polls _polls )
    ReadsAzimuth(_azimuth)
    internal
  {
    previousEcliptic = _previous;
    polls = _polls;
  }

  //  onUpgrade(): called by previous ecliptic when upgrading
  //
  //    in future ecliptics, this might perform more logic than
  //    just simple checks and verifications.
  //    when overriding this, make sure to call the original as well.
  //
  function onUpgrade()
    external
  {
    //  make sure this is the expected upgrade path,
    //  and that we have gotten the ownership we require
    //
    require( msg.sender == previousEcliptic &&
             this == azimuth.owner() &&
             this == polls.owner() );
  }

  //  upgrade(): transfer ownership of the ecliptic data to the new
  //             ecliptic contract, notify it, then self-destruct.
  //
  //    Note: any eth that have somehow ended up in the contract are also
  //          sent to the new ecliptic.
  //
  function upgrade(EclipticBase _new)
    internal
  {
    //  transfer ownership of the data contracts
    //
    azimuth.transferOwnership(_new);
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
