// simple reputations store
// draft

pragma solidity 0.4.18;

import './Ships.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Censures is Ownable
{
  //TODO indexed
  event Censured(uint32 by, uint32 who);
  event Forgiven(uint32 by, uint32 who);

  Ships public ships;

  // per ship: censures.
  mapping(uint32 => uint32[]) public censures;
  // per ship: per censure: index in censures array (for efficient deletions).
  //NOTE these describe the "nth array element", so they're at index n-1.
  mapping(uint32 => mapping(uint32 => uint256)) public indices;

  function Censures(Ships _ships)
    public
  {
    ships = _ships;
  }

  // since it's currently "not possible to return dynamic content from external
  // function calls" we must expose this as an interface to allow in-contract
  // discoverability of someone's censure count.
  function getCensureCount(uint32 _whose)
    view
    public
    returns (uint256 count)
  {
    return censures[_whose].length;
  }

  function getCensures(uint32 _whose)
    view
    public
    returns (uint32[] cens)
  {
    return censures[_whose];
  }

  function censure(uint32 _as, uint32 _who)
    external
    pilot(_as)
  {
    require(_as != _who
            && indices[_as][_who] == 0
            && censures[_as].length < 16);
    // only for stars and galaxies.
    // stars may only censure other stars, galaxies may censure both.
    uint8 asClass = getShipClass(_as);
    uint8 whoClass = getShipClass(_who);
    require(asClass < 2
            && whoClass < 2
            && whoClass >= asClass);
    censures[_as].push(_who);
    indices[_as][_who] = censures[_as].length;
    Censured(_as, _who);
  }

  function forgive(uint32 _as, uint32 _who)
    external
    pilot(_as)
  {
    // we don't need to do any convoluted checks here.
    // for those not allowed to censure, there's nothing to forgive.
    // we delete the target from the list, then fill the gap with the list tail.
    // retrieve current index.
    uint256 i = indices[_as][_who];
    require(i > 0);
    i--;
    // copy last item to current index.
    uint32[] storage cens = censures[_as];
    uint256 last = cens.length - 1;
    cens[i] = cens[last];
    // delete last item.
    delete(cens[last]);
    cens.length = last;
    indices[_as][_who] = 0;
    Forgiven(_as, _who);
  }

  // get the class of the ship
  //TODO duplicate from constitution, should probably move into ships.
  function getShipClass(uint32 _ship)
    public
    pure
    returns (uint8 _class)
  {
    if (_ship < 256) return 0;
    if (_ship < 65536) return 1;
    return 2;
  }

  // test if msg.sender is pilot of _ship.
  modifier pilot(uint32 _ship)
  {
    require(ships.isPilot(_ship, msg.sender));
    _;
  }
}
