//  simple claims store

pragma solidity 0.4.24;

import './Ships.sol';

//  Claims: simple identity management
//
//    This contract allows ships to document claims about their owner.
//    Most commonly, these are about identity, with a claim's protocol
//    defining the context or platform of the claim, and its dossier
//    containing proof of its validity.
//
//    For existing claims, the dossier can be updated, or the claim can
//    be removed entirely. It is recommended to remove any claims associated
//    with a ship when it is about to be transfered to a new owner.
//
contract Claims
{
  //  Claimed: a claim was made by :by
  //
  event Claimed(uint32 by, string _protocol, string _claim, bytes _dossier);

  //  Disclaimed: a claim was disclaimed by :by
  //
  event Disclaimed(uint32 by, string _protocol, string _claim);

  //  ships: ships data storage
  //
  Ships public ships;

  //  Claim: claim details
  //
  struct Claim
  {
    //  protocol: context of the claim
    //
    string protocol;

    //  claim: the claim itself
    //
    string claim;

    //  dossier: data relating to the claim, as proof
    //
    bytes dossier;
  }

  //  per ship: list of claims made
  //
  mapping(uint32 => Claim[]) public claims;

  //  indexes: per ship, per claim hash, (index + 1) in claims array
  //
  //    We delete claims by moving the last entry in the array to the
  //    newly emptied slot, which is (n - 1) where n is the value of
  //    indexes[ship][claimHash].
  //    We use hashes because structures can't be used as keys.
  //
  mapping(uint32 => mapping(bytes32 => uint256)) public indexes;

  //  constructor(): register the ships contract.
  //
  constructor(Ships _ships)
    public
  {
    ships = _ships;
  }

  //  getClaimCount(): return the length of the array of claims made by _whose
  //
  function getClaimCount(uint32 _whose)
    view
    public
    returns (uint256 count)
  {
    return claims[_whose].length;
  }

  //  claim(): register a claim as _as
  //
  function claim(uint32 _as, string _protocol, string _claim, bytes _dossier)
    external
    shipOwner(_as)
  {
    //  may only submit up to 16 claims
    //
    require(claims[_as].length < 16);

    //  id: a unique identifier for this claim
    //
    bytes32 id = claimId(_protocol, _claim);

    //  cur: index + 1 of the claim if it already exists, 0 otherwise
    //
    uint256 cur = indexes[_as][id];

    //  if the claim doesn't yet exist, store it in state
    //
    if (cur == 0)
    {
      claims[_as].push(Claim(_protocol, _claim, _dossier));
      indexes[_as][id] = claims[_as].length;
    }
    //
    //  if the claim has been made before, update the version in state
    //
    else
    {
      claims[_as][cur-1] = Claim(_protocol, _claim, _dossier);
    }
    emit Claimed(_as, _protocol, _claim, _dossier);
  }

  //  disclaim(): unregister a claim as _as
  //
  function disclaim(uint32 _as, string _protocol, string _claim)
    external
    shipOwner(_as)
  {
    //  id: unique identifier of this claim
    //
    bytes32 id = claimId(_protocol, _claim);

    //  i: current index in _as's list of censures
    //
    uint256 i = indexes[_as][id];

    //  we store index + 1, because 0 is the eth default value
    //  can only delete an existing claim
    //
    require(i > 0);
    i--;

    //  copy last item in the list into the now-unused slot
    //
    Claim[] storage clams = claims[_as];
    uint256 last = clams.length - 1;
    clams[i] = clams[last];

    //  delete the last item
    //
    delete(clams[last]);
    clams.length = last;
    indexes[_as][id] = 0;
    emit Disclaimed(_as, _protocol, _claim);
  }

  //  clearClaims(): unregister all of _as's claims
  //
  //    can also be called by the constitution during ship transfer
  //
  function clearClaims(uint32 _as)
    external
  {
    //  both ship owner and constitution may do this
    //
    require( ships.isOwner(_as, msg.sender) ||
             ( msg.sender == ships.owner() ) );

    Claim[] storage clams = claims[_as];

    //  clear out the indexes mapping
    //
    //    this has an upper bound of 16 iterations due to the claims limit
    //
    for (uint8 i = 0; i < clams.length; i++)
    {
      Claim storage clam = clams[i];
      indexes[_as][claimId(clam.protocol, clam.claim)] = 0;
    }

    //  lastly, remove all claims from storage
    //
    clams.length = 0;
  }

  //  claimId(): generate a unique identifier for a claim
  //
  function claimId(string _protocol, string _claim)
    pure
    public
    returns (bytes32 id)
  {
    return keccak256(abi.encodePacked(
             keccak256(abi.encodePacked(_protocol)),
             _claim ));
  }

  //  shipOwner(): require that :msg.sender is the owner of _ship
  //
  modifier shipOwner(uint32 _ship)
  {
    require(ships.isOwner(_ship, msg.sender));
    _;
  }
}
