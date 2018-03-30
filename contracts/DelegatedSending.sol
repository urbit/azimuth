// simple planet invitation management contract
// draft

pragma solidity 0.4.18;

import './Constitution.sol';

contract DelegatedSending
{
  //  Sent: :by sent :ship.
  //
  event Sent(uint32 by, uint32 ship);

  //  ships: the ships contract
  //
  Ships public ships;

  //  limits: per star, the maximum amount of planets any of its planets may
  //          give away
  //
  mapping(uint16 => uint16) public limits;

  //  sent: per planet, the amount of planets they have sent
  //
  mapping(uint32 => uint16) public sent;

  //  DelegatedSending(): register the ships contract
  //
  function DelegatedSending(Ships _ships)
    public
  {
    ships = _ships;
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

  //  sendShip(): as the ship _as, spawn the ship _ship to _to.
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
    sent[_as] = sent[_as] + 1;

    //  grant _to ownership of _ship.
    //
    Constitution(ships.owner()).spawn(_ship, _to);

    Sent(_as, _ship);
  }

  //  canSend(): check whether current conditions allow _as to send _ship
  //
  function canSend(uint32 _as, uint32 _ship)
    public
    view
    returns (bool result)
  {
    uint16 prefix = ships.getPrefix(_as);
    return ( //  can only send ships with the same prefix
             //
             (prefix == ships.getPrefix(_ship)) &&
             //
             //  _as must not have hit the allowed limit yet
             //
             (sent[_as] < limits[prefix]) &&
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

  //  shipOwner(): require that :msg.sender is the owner of _ship
  //
  modifier shipOwner(uint32 _ship)
  {
    require(ships.isOwner(_ship, msg.sender));
    _;
  }
}
