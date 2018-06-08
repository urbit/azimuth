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
  event Sent(uint32 by, uint32 ship);

  //  limits: per star, the maximum amount of planets any of its planets may
  //          give away
  //
  mapping(uint16 => uint16) public limits;

  //  pools: per planet, the amount of planets that have been given away by
  //         the planet itself or the ones it invited
  //
  mapping(uint32 => uint16) public pools;

  //  fromPool: per planet, the pool from which they were sent
  //
  mapping(uint32 => uint32) public fromPool;

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
    shipOwner(_prefix)
  {
    limits[_prefix] = _limit;
  }

  //  resetPool(): grant _for their own invite pool in case they still
  //               share one and reset its counter to zero
  //
  function resetPool(uint32 _for)
    external
    shipOwner(ships.getPrefix(_for))
  {
    fromPool[_for] = 0;
    pools[_for] = 0;
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
    shipOwner(_as)
  {
    require(canSend(_as, _ship));

    //  caller may not send to themselves
    //
    require(msg.sender != _to);


    //  increment the sent counter for _as.
    //
    uint32 pool = getPool(_as);
    pools[pool] = pools[pool] + 1;

    //  associate the _ship with this pool
    //
    fromPool[_ship] = pool;

    //  grant _to ownership of _ship.
    //
    Constitution(ships.owner()).spawn(_ship, _to);

    emit Sent(_as, _ship);
  }

  //  canSend(): check whether current conditions allow _as to send _ship
  //
  function canSend(uint32 _as, uint32 _ship)
    public
    view
    returns (bool result)
  {
    uint16 prefix = ships.getPrefix(_as);
    uint32 pool = getPool(_as);
    return ( //  can only send ships with the same prefix
             //
             (prefix == ships.getPrefix(_ship)) &&
             //
             //  _as must not have hit the allowed limit yet
             //
             (pools[pool] < limits[prefix]) &&
             //
             //  _ship needs to be inactive
             //
             !ships.isActive(_ship) &&
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
    returns (uint32 pool)
  {
    pool = fromPool[_ship];

    //  no pool explicitly registered means they have their own pool
    //
    if (0 == pool)
    {
      return _ship;
    }
  }
}
