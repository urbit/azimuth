//  simple reputations store

pragma solidity 0.4.18;

import './Ships.sol';

contract Censures
{
  //  Censured: :who got censures by :by
  //
  event Censured(uint32 by, uint32 who);

  //  Forgiven: :who is no longer censured by :by
  //
  event Forgiven(uint32 by, uint32 who);

  //  ships: ships data storage
  //
  Ships public ships;

  //  censures: per ship, their registered censures
  //
  mapping(uint32 => uint32[]) public censures;

  //  indexes: per ship per censure, (index + 1) in censures array
  //
  //    We delete censures by moving the last entry in the array to the
  //    newly emptied slot, which is (n - 1) where n is the value of
  //    indexes[ship][censure].
  //
  mapping(uint32 => mapping(uint32 => uint256)) public indexes;

  //  Censures(): register the ships contract
  //
  function Censures(Ships _ships)
    public
  {
    ships = _ships;
  }

  //  getCensureCount(): return length of array of censures made by _whose
  //
  function getCensureCount(uint32 _whose)
    view
    public
    returns (uint256 count)
  {
    return censures[_whose].length;
  }

  //  getCensures(): return array of censures made by _whose
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getCensures(uint32 _whose)
    view
    public
    returns (uint32[] cens)
  {
    return censures[_whose];
  }

  //  censure(): register a censure of _who as _as
  //
  function censure(uint32 _as, uint32 _who)
    external
    shipOwner(_as)
  {
    require( //  can't censure self
             //
             (_as != _who) &&
             //
             //  must not haven censured _who already
             //
             (indexes[_as][_who] == 0) &&
             //
             //  may only censure up to 16 ships
             //
             (censures[_as].length < 16) );

    //  only stars and galaxies may censure, and only galaxies may censure
    //  other galaxies
    //
    Ships.Class asClass = ships.getShipClass(_as);
    Ships.Class whoClass = ships.getShipClass(_who);
    require( (asClass < Ships.Class.Planet) &&
             (whoClass < Ships.Class.Planet) &&
             (whoClass >= asClass) );

    //  update contract state with the new censure
    //
    censures[_as].push(_who);
    indexes[_as][_who] = censures[_as].length;
    Censured(_as, _who);
  }

  //  forgive(): unregister a censure of _who as _as
  //
  function forgive(uint32 _as, uint32 _who)
    external
    shipOwner(_as)
  {
    //  i: current index in _as's list of censures
    //
    uint256 i = indexes[_as][_who];

    //  we store index + 1, because 0 is the eth default value
    //  can only delete an existing censure
    //
    require(i > 0);
    i--;

    //  copy last item in the list into the now-unused slot
    //
    uint32[] storage cens = censures[_as];
    uint256 last = cens.length - 1;
    cens[i] = cens[last];

    //  delete the last item
    //
    delete(cens[last]);
    cens.length = last;
    indexes[_as][_who] = 0;
    Forgiven(_as, _who);
  }

  //  shipOwner(): require that :msg.sender is the owner of _ship
  //
  modifier shipOwner(uint32 _ship)
  {
    require(ships.isOwner(_ship, msg.sender));
    _;
  }
}
