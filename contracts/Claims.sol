//  simple claims store

pragma solidity 0.4.24;

import './ReadsShips.sol';

//  Claims: simple identity management
//
//    This contract allows ships to document claims about their owner.
//    Most commonly, these are about identity, with a claim's protocol
//    defining the context or platform of the claim, and its dossier
//    containing proof of its validity.
//    Ships are limited to a maximum of 16 claims.
//
//    For existing claims, the dossier can be updated, or the claim can
//    be removed entirely. It is recommended to remove any claims associated
//    with a ship when it is about to be transfered to a new owner.
//    For convenience, the owner of the Ships contract (the Constitution)
//    is allowed to clear claims for any ship, allowing it to do this for
//    you on-transfer.
//
contract Claims is ReadsShips
{
  //  ClaimAdded: a claim was addhd by :by
  //
  event ClaimAdded( uint32 indexed by,
                    string _protocol,
                    string _claim,
                    bytes _dossier );

  //  ClaimRemoved: a claim was removed by :by
  //
  event ClaimRemoved(uint32 indexed by, string _protocol, string _claim);

  //  maxClaims: the amount of claims that can be registered per ship
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

  //  per ship, list of claims
  //
  mapping(uint32 => Claim[maxClaims]) public claims;

  //  constructor(): register the ships contract.
  //
  constructor(Ships _ships)
    ReadsShips(_ships)
    public
  {
    //
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
    //  cur: index + 1 of the claim if it already exists, 0 otherwise
    //
    uint8 cur = findClaim(_ship, _protocol, _claim);

    //  if the claim doesn't yet exist, store it in state
    //
    if (cur == 0)
    {
      //  if there are no empty slots left, this throws
      //
      uint8 empty = findEmptySlot(_ship);
      claims[_ship][empty] = Claim(_protocol, _claim, _dossier);
    }
    //
    //  if the claim has been made before, update the version in state
    //
    else
    {
      claims[_ship][cur-1] = Claim(_protocol, _claim, _dossier);
    }
    emit ClaimAdded(_ship, _protocol, _claim, _dossier);
  }

  //  removeClaim(): unregister a claim as _ship
  //
  function removeClaim(uint32 _ship, string _protocol, string _claim)
    external
    shipOwner(_ship)
  {
    //  i: current index + 1 in _ship's list of claims
    //
    uint256 i = findClaim(_ship, _protocol, _claim);

    //  we store index + 1, because 0 is the eth default value
    //  can only delete an existing claim
    //
    require(i > 0);
    i--;

    //  clear out the claim
    //
    claims[_ship][i] = Claim('', '', '');

    emit ClaimRemoved(_ship, _protocol, _claim);
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

    Claim[maxClaims] storage currClaims = claims[_ship];

    //  clear out all claims
    //
    for (uint8 i = 0; i < maxClaims; i++)
    {
      currClaims[i] = Claim('', '', '');
    }
  }

  //  findClaim(): find the index of the specified claim
  //
  //    returns 0 if not found, index + 1 otherwise
  //
  function findClaim(uint32 _whose, string _protocol, string _claim)
    public
    view
    returns (uint8 index)
  {
    bytes32 protocolHash = keccak256(bytes(_protocol));
    bytes32 claimHash = keccak256(bytes(_claim));
    Claim[maxClaims] storage theirClaims = claims[_whose];
    for (uint8 i = 0; i < maxClaims; i++)
    {
      Claim storage thisClaim = theirClaims[i];
      if ( ( protocolHash == keccak256(bytes(thisClaim.protocol)) ) &&
           ( claimHash == keccak256(bytes(thisClaim.claim)) ) )
      {
        return i+1;
      }
    }
    return 0;
  }

  //  findEmptySlot(): find the index of the first empty claim slot
  //
  //    returns the index of the slot, throws if there are no empty slots
  //
  function findEmptySlot(uint32 _whose)
    internal
    view
    returns (uint8 index)
  {
    Claim[maxClaims] storage theirClaims = claims[_whose];
    for (uint8 i = 0; i < maxClaims; i++)
    {
      Claim storage thisClaim = theirClaims[i];
      if ( (0 == bytes(thisClaim.protocol).length) &&
           (0 == bytes(thisClaim.claim).length) )
      {
        return i;
      }
    }
    revert();
  }
}
