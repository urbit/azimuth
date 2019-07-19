//  simple planet invitation management contract
//  https://azimuth.network

pragma solidity 0.4.24;

import './Ecliptic.sol';

//  DelegatedSending: invite-like point sending
//
//    This contract allows planet owners to gift planets to their friends,
//    if a star has allowed it.
//
//    Star owners can grant a number of "invites" to planets. An "invite" in
//    the context of this contract means a planet from the same parent star,
//    that can be sent to an Ethereum address that owns no points.
//    Planets that were sent as invites are also allowed to send invites, but
//    instead of adhering to a star-set limit, they will use up invites from
//    the same "pool" as their inviter.
//
//    To allow planets to be sent by this contract, stars must set it as
//    their spawnProxy using the Ecliptic.
//
contract DelegatedSending is ReadsAzimuth
{
  //  Pool: :who was given their own pool by :prefix, of :size invites
  //
  event Pool(uint16 indexed prefix, uint32 indexed who, uint16 size);

  //  Sent: :by sent :point
  //
  event Sent( uint16 indexed prefix,
              uint32 indexed fromPool,
              uint32 by,
              uint32 point,
              address to);

  //  pools: per pool, the amount of planets that can still be given away
  //         per star by the pool's planet itself or the ones it invited
  //
  //    pools are associated with planets by number,
  //    then with stars by number.
  //    pool 0 does not exist, and is used symbolically by :fromPool.
  //
  mapping(uint32 => mapping(uint16 => uint16)) public pools;

  //  fromPool: per planet, the pool from which they send invites
  //
  //    when invited by planet n, the invitee sends from n's pool.
  //    a pool of 0 means the planet has its own invite pool.
  //
  mapping(uint32 => uint32) public fromPool;

  //  poolStars: per pool, the stars from which it has received invites
  //
  mapping(uint32 => uint16[]) public poolStars;

  //  poolStarsRegistered: per pool, per star, whether or not it is in
  //                       the :poolStars array
  //
  mapping(uint32 => mapping(uint16 => bool)) public poolStarsRegistered;

  //  inviters: points with their own pools, invite tree roots
  //
  uint32[] public inviters;

  //  isInviter: whether or not a point is in the :inviters list
  //
  mapping(uint32 => bool) public isInviter;

  //  invited: for each point, the points they invited
  //
  mapping(uint32 => uint32[]) public invited;

  //  invitedBy: for each point, the point they were invited by
  //
  mapping(uint32 => uint32) public invitedBy;

  //  constructor(): register the azimuth contract
  //
  constructor(Azimuth _azimuth)
    ReadsAzimuth(_azimuth)
    public
  {
    //
  }

  //  setPoolSize(): give _for their own pool if they don't have one already,
  //                 and allow them to send _size points from _as
  //
  function setPoolSize(uint16 _as, uint32 _for, uint16 _size)
    external
    activePointOwner(_as)
  {
    fromPool[_for] = 0;
    pools[_for][_as] = _size;

    //  register star as having given invites to pool,
    //  if that hasn't happened yet
    //
    if (false == poolStarsRegistered[_for][_as]) {
      poolStars[_for].push(_as);
      poolStarsRegistered[_for][_as] = true;
    }

    //  add _for as an invite tree root
    //
    if (false == isInviter[_for])
    {
      isInviter[_for] = true;
      inviters.push(_for);
    }

    emit Pool(azimuth.getPrefix(_for), _for, _size);
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

    //  remove an invite from _as' current pool
    //
    uint32 pool = getPool(_as);
    uint16 prefix = azimuth.getPrefix(_point);
    pools[pool][prefix]--;

    //  associate the _point with this pool
    //
    fromPool[_point] = pool;

    //  add _point to _as' invite tree
    //
    invited[_as].push(_point);
    invitedBy[_point] = _as;

    //  spawn _point to _to, they still need to accept the transfer manually
    //
    Ecliptic(azimuth.owner()).spawn(_point, _to);

    emit Sent(prefix, pool, _as, _point, _to);
  }

  //  canSend(): check whether current conditions allow _as to send _point
  //
  function canSend(uint32 _as, uint32 _point)
    public
    view
    returns (bool result)
  {
    uint16 prefix = azimuth.getPrefix(_point);
    uint32 pool = getPool(_as);
    return ( //  _as' pool for this prefix must not have been exhausted yet
             //
             (0 < pools[pool][prefix]) &&
             //
             //  _point needs to not be (in the process of being) spawned
             //
             azimuth.isOwner(_point, 0x0) &&
             //
             //  this contract must have permission to spawn points
             //
             azimuth.isSpawnProxy(prefix, this) &&
             //
             //  the prefix must be linked
             //
             azimuth.hasBeenLinked(prefix) &&
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
    public
    view
    returns (uint32 pool)
  {
    pool = fromPool[_point];

    //  no pool explicitly registered means they have their own pool,
    //  because they either were not invited by this contract, or have
    //  been granted their own pool by their star.
    //
    if (0 == pool)
    {
      //  send from the planet's own pool, see also :fromPool
      //
      return _point;
    }

    return pool;
  }

  //  canReceive(): whether the _recipient is eligible to receive a planet
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

  //  getPoolStars(): returns a list of stars _who has pools for
  //
  function getPoolStars(uint32 _who)
    external
    view
    returns (uint16[] stars)
  {
    return poolStars[_who];
  }

  //  getInviters(): returns a list of all points with their own pools
  //
  function getInviters()
    external
    view
    returns (uint32[] invs)
  {
    return inviters;
  }

  //  getInvited(): returns a list of points invited by _who
  //
  function getInvited(uint32 _who)
    external
    view
    returns (uint32[] invd)
  {
    return invited[_who];
  }
}
