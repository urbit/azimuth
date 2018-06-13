//  simple reputations store

pragma solidity 0.4.24;

import './ReadsShips.sol';

//  Censures: simple reputation management
//
//    This contract allows stars and galaxies to assign a negative
//    reputation (censure) to other ships of the same or lower rank.
//    These censures are not permanent, they can be forgiven.
//
//    Since the Urbit network provides incentives for good behavior,
//    making bad behavior is the exception rather than the rule, this
//    only provides registration of negative reputation.
//
contract Censures is ReadsShips
{
  //  Censured: :who got censures by :by
  //
  event Censured(uint16 indexed by, uint32 indexed who);

  //  Forgiven: :who is no longer censured by :by
  //
  event Forgiven(uint16 indexed by, uint32 indexed who);

  //  censuring: per ship, the ships they're censuring
  //
  mapping(uint16 => uint32[]) public censuring;

  //  censuredBy: per ship, those who have censured them
  //
  mapping(uint32 => uint16[]) public censuredBy;

  //  censuringIndexes: per ship per censure, (index + 1) in censures array
  //
  //    We delete censures by moving the last entry in the array to the
  //    newly emptied slot, which is (n - 1) where n is the value of
  //    indexes[ship][censure].
  //
  mapping(uint16 => mapping(uint32 => uint256)) public censuringIndexes;

  //  censuredByIndexes: per censure per ship, (index + 1) in censured array
  //
  //    see also explanation for indexes_censures above
  //
  mapping(uint32 => mapping(uint16 => uint256)) public censuredByIndexes;

  //  constructor(): register the ships contract
  //
  constructor(Ships _ships)
    ReadsShips(_ships)
    public
  {
    //
  }

  //  getCensuringCount(): return length of array of censures made by _whose
  //
  function getCensuringCount(uint16 _whose)
    view
    public
    returns (uint256 count)
  {
    return censuring[_whose].length;
  }

  //  getCensuring(): return array of censures made by _whose
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getCensuring(uint16 _whose)
    view
    public
    returns (uint32[] cens)
  {
    return censuring[_whose];
  }

  //  getCensuredByCount(): return length of array of censures made against _who
  //
  function getCensuredByCount(uint16 _who)
    view
    public
    returns (uint256 count)
  {
    return censuredBy[_who].length;
  }

  //  getCensuredBy(): return array of censures made against _who
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getCensuredBy(uint16 _who)
    view
    public
    returns (uint16[] cens)
  {
    return censuredBy[_who];
  }

  //  censure(): register a censure of _who as _as
  //
  function censure(uint16 _as, uint32 _who)
    external
    activeShipOwner(_as)
  {
    require( //  can't censure self
             //
             (_as != _who) &&
             //
             //  must not haven censured _who already
             //
             (censuringIndexes[_as][_who] == 0) );

    //  only stars and galaxies may censure, and only galaxies may censure
    //  other galaxies. (enum gets smaller for higher ship classes)
    //
    Ships.Class asClass = ships.getShipClass(_as);
    Ships.Class whoClass = ships.getShipClass(_who);
    require( whoClass >= asClass );

    //  update contract state with the new censure
    //
    censuring[_as].push(_who);
    censuringIndexes[_as][_who] = censuring[_as].length;

    //  and update the reverse lookup
    //
    censuredBy[_who].push(_as);
    censuredByIndexes[_who][_as] = censuredBy[_who].length;

    emit Censured(_as, _who);
  }

  //  forgive(): unregister a censure of _who as _as
  //
  function forgive(uint16 _as, uint32 _who)
    external
    shipOwner(_as)
  {
    //  below, we perform the same logic twice: once on the canonical data,
    //  and once on the reverse lookup
    //
    //  i: current index in _as's list of censures
    //  j: current index in _who's list of ships that have censured it
    //
    uint256 i = censuringIndexes[_as][_who];
    uint256 j = censuredByIndexes[_who][_as];

    //  we store index + 1, because 0 is the eth default value
    //  can only delete an existing censure
    //
    require( (i > 0) && (j > 0) );
    i--;
    j--;

    //  copy last item in the list into the now-unused slot,
    //  making sure to update the :indexes_ references
    //
    uint32[] storage cens = censuring[_as];
    uint16[] storage cend = censuredBy[_who];
    uint256 lastCens = cens.length - 1;
    uint256 lastCend = cend.length - 1;
    uint32 movedCens = cens[lastCens];
    uint16 movedCend = cend[lastCend];
    cens[i] = movedCens;
    cend[j] = movedCend;
    censuringIndexes[_as][movedCens] = i + 1;
    censuredByIndexes[_who][movedCend] = j + 1;

    //  delete the last item
    //
    cens.length = lastCens;
    cend.length = lastCend;
    censuringIndexes[_as][_who] = 0;
    censuredByIndexes[_who][_as] = 0;

    emit Forgiven(_as, _who);
  }
}
