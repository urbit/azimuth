//  contract that takes and gives Azimuth points

pragma solidity 0.4.24;

import './Ecliptic.sol';
import './ReadsAzimuth.sol';

contract TakesPoints is ReadsAzimuth
{
  constructor(Azimuth _azimuth)
    ReadsAzimuth(_azimuth)
    public
  {
    //
  }

  //  takePoint(): transfer _point to this contract. if _clean is true, require
  //               that the point be unused.
  //               returns true if this succeeds, false otherwise.
  //
  function takePoint(uint32 _point, bool _clean)
    internal
    returns (bool success)
  {
    Ecliptic ecliptic = Ecliptic(azimuth.owner());

    //  There are two ways for a contract to get a point.
    //  One way is for a prefix point to grant the contract permission to
    //  spawn its points.
    //  The contract will spawn the point directly to itself.
    //
    uint16 prefix = azimuth.getPrefix(_point);
    if ( azimuth.isOwner(_point, 0x0) &&
         azimuth.isOwner(prefix, msg.sender) &&
         azimuth.isSpawnProxy(prefix, this) &&
         (ecliptic.getSpawnLimit(prefix, now) > azimuth.getSpawnCount(prefix)) )
    {
      //  first model: spawn _point to :this contract
      //
      ecliptic.spawn(_point, this);
      return true;
    }

    //  The second way is to accept existing points, optionally
    //  requiring they be unused.
    //  To deposit a point this way, the owner grants the contract
    //  permission to transfer ownership of the point.
    //  The contract will transfer the point to itself.
    //
    if ( (!_clean || !azimuth.hasBeenUsed(_point)) &&
         azimuth.isOwner(_point, msg.sender) &&
         azimuth.canTransfer(_point, this) )
    {
      //  second model: transfer active, unused _point to :this contract
      //
      ecliptic.transferPoint(_point, this, true);
      return true;
    }

    //  point is not for us to take
    //
    return false;
  }

  //  givePoint(): transfer a _point we own to _to, optionally resetting.
  //               returns true if this succeeds, false otherwise.
  //
  //    Note that _reset is unnecessary if the point was taken
  //    using this contract's takePoint() function, which always
  //    resets, and not touched since.
  //
  function givePoint(uint32 _point, address _to, bool _reset)
    internal
    returns (bool success)
  {
    //  only give points we've taken, points we fully own
    //
    if (azimuth.isOwner(_point, this))
    {
      Ecliptic(azimuth.owner()).transferPoint(_point, _to, _reset);
      return true;
    }

    //  point is not for us to give
    //
    return false;
  }
}
