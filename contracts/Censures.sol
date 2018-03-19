// simple reputations store
// draft

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Censures is Ownable
{
  //TODO indexed
  event Censured(uint32 by, uint32 who);
  event Forgiven(uint32 by, uint32 who);

  // per ship: censures.
  mapping(uint32 => uint32[]) public censures;
  // per ship: per censure: index in censures array (for efficient deletions).
  //NOTE these describe the "nth array element", so they're at index n-1.
  mapping(uint32 => mapping(uint32 => uint256)) public indices;

  function Reputations()
    public
  {
    //
  }

  // since it's currently "not possible to return dynamic content from external
  // function calls" we must expose this as an interface to allow in-contract
  // discoverability of someone's "balance".
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
    onlyOwner
    public
  {
    require(indices[_as][_who] == 0);
    censures[_as].push(_who);
    indices[_as][_who] = censures[_as].length;
    Censured(_as, _who);
  }

  function forgive(uint32 _as, uint32 _who)
    onlyOwner
    public
  {
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
}
