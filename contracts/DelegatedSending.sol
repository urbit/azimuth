//  simple planet invitation management contract

pragma solidity 0.4.24;

import './Ecliptic.sol';

//  DelegatedSending: invite-like point sending
//
//    This contract allows planet owners to gift planets to their friends,
//    if their prefix has allowed it.
//
//    Star owners can set a limit, the amount of "invite planets" each of
//    their planets is allowed to send. Enabling this by setting the limit
//    to a value higher than zero can help the network grow by providing
//    regular users with a way to get their friends and family onto it.
//
//    To allow planets to be sent my this contract, stars must set it as
//    their spawnProxy using the Ecliptic.
//
contract DelegatedSending is ReadsAzimuth
{
  //  Sent: :by sent :point
  //
  event Sent( uint16 indexed prefix,
              uint64 indexed fromPool,
              uint32 by,
              uint32 point,
              address to);

  //  limits: per star, the maximum amount of planets any of its planets may
  //          give away
  //
  mapping(uint16 => uint16) public limits;

  //  pools: per pool, the amount of planets that have been given away by
  //         the pool's planet itself or the ones it invited
  //
  //    pools are associated with planets by number, pool n belongs to
  //    planet n - 1.
  //    pool 0 does not exist, and is used symbolically by :fromPool.
  //
  mapping(uint64 => uint16) public pools;

  //  fromPool: per planet, the pool from which they were sent
  //
  //    when invited by planet n, the invitee is registered in pool n + 1.
  //    a pool of 0 means the planet has its own invite pool.
  //    this is done so that all planets that were born outside of this
  //    contract start out with their own pool (0, solidity default),
  //    while we configure planets created through this contract to use
  //    their inviter's pool.
  //
  mapping(uint32 => uint64) public fromPool;

  //  constructor(): register the azimuth contract
  //
  constructor(Azimuth _azimuth)
    ReadsAzimuth(_azimuth)
    public
  {
    //
  }

  //  configureLimit(): as the owner of a star, configure the amount of
  //                    planets that may be given away per point.
  //
  function configureLimit(uint16 _prefix, uint16 _limit)
    external
    activePointOwner(_prefix)
  {
    limits[_prefix] = _limit;
  }

  //  resetPool(): grant _for their own invite pool in case they still
  //               share one and reset its counter to zero
  //
  function resetPool(uint32 _for)
    external
    activePointOwner(azimuth.getPrefix(_for))
  {
    fromPool[_for] = 0;
    pools[uint64(_for) + 1] = 0;
  }

  //  sendPoint(): as the point _as, spawn the point _point to _to.
  //
  //    Requirements:
  //    - :msg.sender must be the owner of _as,
  //    - _to must not be the :msg.sender,
  //    - _as must be able to send the _point according to canSend()
  //
  function sendPoint(uint32 _as, uint32 _point, address _to)
    external
    activePointOwner(_as)
  {
    require(canSend(_as, _point));

    //  caller may not send to themselves
    //
    require(msg.sender != _to);

    //  recipient must be eligible to receive a planet from this contract
    //
    require(canReceive(_to));

    //  increment the sent counter for _as.
    //
    uint64 pool = getPool(_as);
    pools[pool] = pools[pool] + 1;

    //  associate the _point with this pool
    //
    fromPool[_point] = pool;

    //  spawn _point to _to, they still need to accept the transfer manually
    //
    Ecliptic(azimuth.owner()).spawn(_point, _to);

    emit Sent(azimuth.getPrefix(_point), pool, _as, _point, _to);
  }

  //  canSend(): check whether current conditions allow _as to send _point
  //
  function canSend(uint32 _as, uint32 _point)
    public
    view
    returns (bool result)
  {
    uint16 prefix = azimuth.getPrefix(_as);
    uint64 pool = getPool(_as);
    return ( //  can only send points with the same prefix
             //
             (prefix == azimuth.getPrefix(_point)) &&
             //
             //  _as must not have hit the allowed limit yet
             //
             (pools[pool] < limits[prefix]) &&
             //
             //  _point needs to not be (in the process of being) spawned
             //
             azimuth.isOwner(_point, 0x0) &&
             //
             //  this contract must have permission to spawn points
             //
             azimuth.isSpawnProxy(prefix, this) &&
             //
             //  the prefix must be in use
             //
             azimuth.hasBeenUsed(prefix) &&
             //
             //  the prefix must not have hit its spawn limit yet
             //
             ( azimuth.getSpawnCount(prefix) <
               Ecliptic(azimuth.owner())
               .getSpawnLimit(prefix, block.timestamp) ) );
  }

  //  getPool(): get the invite pool _point belongs to
  //
  function getPool(uint32 _point)
    internal
    view
    returns (uint64 pool)
  {
    pool = fromPool[_point];

    //  no pool explicitly registered means they have their own pool,
    //  because they either were not invited by this contract, or have
    //  been granted their own pool by their star.
    //
    if (0 == pool)
    {
      //  the pool for planet n is n + 1, see also :fromPool
      //
      return uint64(_point) + 1;
    }
  }

  //  canReceive(): wether the _recipient is eligible to receive a planet
  //                from this contract or not
  //
  //    only those who don't own or are entitled to any points may receive
  //
  function canReceive(address _recipient)
    public
    view
    returns (bool result)
  {
    return ( 0 == azimuth.getOwnedPointCount(_recipient) &&
             0 == azimuth.getTransferringForCount(_recipient) );
  }
}
