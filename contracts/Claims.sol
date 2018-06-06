//  simple claims store

pragma solidity 0.4.24;

import './ReadsShips.sol';

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
contract Claims is ReadsShips
{
  //  Claimed: a claim was made by :by
  //
  event Claimed(uint32 by, string _protocol, string _claim, bytes _dossier);

  //  Disclaimed: a claim was disclaimed by :by
  //
  event Disclaimed(uint32 by, string _protocol, string _claim);

  //  maxClaims: the amount of claims that can be registered per ship.
  //
  uint8 constant maxClaims = 16;

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

  //  indexes: per ship, per claim id, (index + 1) in claims array
  //
  //    We delete claims by moving the last entry in the array to the
  //    newly emptied slot, which is (n - 1) where n is the value of
  //    indexes[ship][claimHash].
  //    We use claim IDs because structures can't be used as keys.
  //
  mapping(uint32 => mapping(bytes32 => uint256)) public indexes;

  //  constructor(): register the ships contract.
  //
  constructor(Ships _ships)
    ReadsShips(_ships)
    public
  {
    //
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

  //  addClaim(): register a claim as _ship
  //
  function addClaim(uint32 _ship,
                    string _protocol,
                    string _claim,
                    bytes _dossier)
    external
    shipOwner(_ship)
  {
    //  may only submit up to :maxClaims claims
    //
    require(claims[_ship].length < maxClaims);

    //  id: a unique identifier for this claim
    //
    bytes32 id = claimId(_protocol, _claim);

    //  cur: index + 1 of the claim if it already exists, 0 otherwise
    //
    uint256 cur = indexes[_ship][id];

    //  if the claim doesn't yet exist, store it in state
    //
    if (cur == 0)
    {
      claims[_ship].push(Claim(_protocol, _claim, _dossier));
      indexes[_ship][id] = claims[_ship].length;
    }
    //
    //  if the claim has been made before, update the version in state
    //
    else
    {
      claims[_ship][cur-1] = Claim(_protocol, _claim, _dossier);
    }
    emit Claimed(_ship, _protocol, _claim, _dossier);
  }

  //  removeClaim(): unregister a claim as _ship
  //
  function removeClaim(uint32 _ship, string _protocol, string _claim)
    external
    shipOwner(_ship)
  {
    //  id: unique identifier of this claim
    //
    bytes32 id = claimId(_protocol, _claim);

    //  i: current index in _ship's list of censures
    //
    uint256 i = indexes[_ship][id];

    //  we store index + 1, because 0 is the eth default value
    //  can only delete an existing claim
    //
    require(i > 0);
    i--;

    //  copy last item in the list into the now-unused slot
    //
    Claim[] storage clams = claims[_ship];
    uint256 last = clams.length - 1;
    clams[i] = clams[last];

    //  delete the last item
    //
    delete(clams[last]);
    clams.length = last;
    indexes[_ship][id] = 0;
    emit Disclaimed(_ship, _protocol, _claim);
  }

  //  clearClaims(): unregister all of _ship's claims
  //
  //    can also be called by the constitution during ship transfer
  //
  function clearClaims(uint32 _ship)
    external
  {
    //  both ship owner and constitution may do this
    //
    require( ships.isOwner(_ship, msg.sender) ||
             ( msg.sender == ships.owner() ) );

    Claim[] storage currClaims = claims[_ship];

    //  clear out the indexes mapping
    //
    //    this has an upper bound of :maxClaims iterations due to that limit
    //
    for (uint8 i = 0; i < currClaims.length; i++)
    {
      Claim storage currClaim = currClaims[i];
      indexes[_ship][claimId(currClaim.protocol, currClaim.claim)] = 0;
    }

    //  lastly, remove all claims from storage
    //
    currClaims.length = 0;
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
}
