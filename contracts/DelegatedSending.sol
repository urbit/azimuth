//  simple planet invitation management contract

pragma solidity 0.4.24;

import './Constitution.sol';

//  DelegatedSending: invite-like ship sending
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
//    their spawnProxy using the Constitution.
//
contract DelegatedSending is ReadsShips
{
  //  Sent: :by sent :ship
  //
  event Sent( uint64 indexed fromPool,
              uint32 indexed by,
              uint32 ship,
              address indexed to);

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

  //  constructor(): register the ships contract
  //
  constructor(Ships _ships)
    ReadsShips(_ships)
    public
  {
    //
  }

  //  configureLimit(): as the owner of a star, configure the amount of
  //                    planets that may be given away per ship.
  //
  function configureLimit(uint16 _prefix, uint16 _limit)
    external
    activeShipOwner(_prefix)
  {
    limits[_prefix] = _limit;
  }

  //  resetPool(): grant _for their own invite pool in case they still
  //               share one and reset its counter to zero
  //
  function resetPool(uint32 _for)
    external
    activeShipOwner(ships.getPrefix(_for))
  {
    fromPool[_for] = 0;
    pools[uint64(_for) + 1] = 0;
  }

  //  sendShip(): as the ship _as, spawn the ship _ship to _to.
  //
  //    Requirements:
  //    - :msg.sender must be the owner of _as,
  //    - _to must not be the :msg.sender,
  //    - _as must be able to send the _ship according to canSend()
  //
  function sendShip(uint32 _as, uint32 _ship, address _to)
    external
    activeShipOwner(_as)
  {
    require(canSend(_as, _ship));

    //  caller may not send to themselves
    //
    require(msg.sender != _to);

    //  recipient must not own or be entitled to any other ships
    //
    require( 0 == ships.getOwnedShipCount(_to) &&
             0 == ships.getTransferringForCount(_to) );

    //  increment the sent counter for _as.
    //
    uint64 pool = getPool(_as);
    pools[pool] = pools[pool] + 1;

    //  associate the _ship with this pool
    //
    fromPool[_ship] = pool;

    //  spawn _ship to _to, they still need to accept the transfer manually
    //
    Constitution(ships.owner()).spawn(_ship, _to);

    emit Sent(pool, _as, _ship, _to);
  }

  //  canSend(): check whether current conditions allow _as to send _ship
  //
  function canSend(uint32 _as, uint32 _ship)
    public
    view
    returns (bool result)
  {
    uint16 prefix = ships.getPrefix(_as);
    uint64 pool = getPool(_as);
    return ( //  can only send ships with the same prefix
             //
             (prefix == ships.getPrefix(_ship)) &&
             //
             //  _as must not have hit the allowed limit yet
             //
             (pools[pool] < limits[prefix]) &&
             //
             //  _ship needs to not be (in the process of being) spawned
             //
             ships.isOwner(_ship, 0x0) &&
             //
             //  this contract must have permission to spawn ships
             //
             ships.isSpawnProxy(prefix, this) &&
             //
             //  the prefix must not have hit its spawn limit yet
             //
             ( ships.getSpawnCount(prefix) <
               Constitution(ships.owner())
               .getSpawnLimit(prefix, block.timestamp) ) &&
             //
             //  the prefix must be live
             //
             ships.hasBeenBooted(prefix) );
  }

  //  getPool(): get the invite pool _ship belongs to
  //
  function getPool(uint32 _ship)
    internal
    view
    returns (uint64 pool)
  {
    pool = fromPool[_ship];

    //  no pool explicitly registered means they have their own pool,
    //  because they either were not invited by this contract, or have
    //  been granted their own pool by their star.
    //
    if (0 == pool)
    {
      //  the pool for planet n is n + 1, see also :fromPool
      //
      return uint64(_ship) + 1;
    }
  }
}
