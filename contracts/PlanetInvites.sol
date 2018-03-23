// simple planet invitation management contract
// draft

pragma solidity 0.4.18;

import './Constitution.sol';

contract PlanetInvites
{
  //TODO do we even ever need events here? mostly covered by Ships.
  event Invited(uint32 by, uint32 who);

  //TODO in this and other contracts, we maybe want
  Ships public ships;

  //TODO uh I'm just going to assume for now that you can only get invites from
  //     your prefix parent. this implementation really is the simplest
  //     possible case
  mapping(uint16 => uint16) public limits;
  mapping(uint32 => uint16) public invited;

  function PlanetInvites(Ships _ships)
    public
  {
    ships = _ships;
  }

  function configureLimit(uint16 _prefix, uint16 _limit)
    external
    owner(_prefix)
  {
    limits[_prefix] = limit;
  }

  function sendShip(uint32 _as, uint32 _invite, address _to)
    external
    owner(_as)
  {
    require(canInvite(_as));
    //TODO is transferring ownership all we need to do in this invite case?
    Constitution(ships.owner()).spawn(_invite, _to);
    invited[_as] = invited[_as] + 1;
    Invited(_as, _invite);
  }

  function canSend(uint32 _as, uint32 _invite)
    public
    view
    returns (bool result)
  {
    uint16 prefix = ships.getPrefix(_ship);
    uint16 invitePrefix = ships.getPrefix(_invite); 
    return ((prefix == invitePrefix)
            && invited[_ship] < limits[prefix]
            && !ships.isActive(_invite)
            && ships.isSpawner(prefix, this)
            && ships.isActive(prefix));
  }

  modifier owner(uint32 _ship)
  {
    require(ships.isOwner(_ship, msg.sender));
    _;
  }
}
