//  simple claims store
//  https://azimuth.network

pragma solidity 0.4.24;

import './ReadsAzimuth.sol';

//  Claims: simple identity management
//
//    This contract allows points to document claims about their owner.
//    Most commonly, these are about identity, with a claim's protocol
//    defining the context or platform of the claim, and its dossier
//    containing proof of its validity.
//    Points are limited to a maximum of 16 claims.
//
//    For existing claims, the dossier can be updated, or the claim can
//    be removed entirely. It is recommended to remove any claims associated
//    with a point when it is about to be transferred to a new owner.
//    For convenience, the owner of the Azimuth contract (the Ecliptic)
//    is allowed to clear claims for any point, allowing it to do this for
//    you on-transfer.
//
contract Claims is ReadsAzimuth
{
  //  ClaimAdded: a claim was added by :by
  //
  event ClaimAdded( uint32 indexed by,
                    string _protocol,
                    string _claim,
                    bytes _dossier );

  //  ClaimRemoved: a claim was removed by :by
  //
  event ClaimRemoved(uint32 indexed by, string _protocol, string _claim);

  //  maxClaims: the amount of claims that can be registered per point
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

  //  per point, list of claims
  //
  mapping(uint32 => Claim[maxClaims]) public claims;

  //  constructor(): register the azimuth contract.
  //
  constructor(Azimuth _azimuth)
    ReadsAzimuth(_azimuth)
    public
  {
    //
  }

  //  addClaim(): register a claim as _point
  //
  function addClaim(uint32 _point,
                    string _protocol,
                    string _claim,
                    bytes _dossier)
    external
    activePointManager(_point)
  {
    //  cur: index + 1 of the claim if it already exists, 0 otherwise
    //
    uint8 cur = findClaim(_point, _protocol, _claim);

    //  if the claim doesn't yet exist, store it in state
    //
    if (cur == 0)
    {
      //  if there are no empty slots left, this throws
      //
      uint8 empty = findEmptySlot(_point);
      claims[_point][empty] = Claim(_protocol, _claim, _dossier);
    }
    //
    //  if the claim has been made before, update the version in state
    //
    else
    {
      claims[_point][cur-1] = Claim(_protocol, _claim, _dossier);
    }
    emit ClaimAdded(_point, _protocol, _claim, _dossier);
  }

  //  removeClaim(): unregister a claim as _point
  //
  function removeClaim(uint32 _point, string _protocol, string _claim)
    external
    activePointManager(_point)
  {
    //  i: current index + 1 in _point's list of claims
    //
    uint256 i = findClaim(_point, _protocol, _claim);

    //  we store index + 1, because 0 is the eth default value
    //  can only delete an existing claim
    //
    require(i > 0);
    i--;

    //  clear out the claim
    //
    delete claims[_point][i];

    emit ClaimRemoved(_point, _protocol, _claim);
  }

  //  clearClaims(): unregister all of _point's claims
  //
  //    can also be called by the ecliptic during point transfer
  //
  function clearClaims(uint32 _point)
    external
  {
    //  both point owner and ecliptic may do this
    //
    //    We do not necessarily need to check for _point's active flag here,
    //    since inactive points cannot have claims set. Doing the check
    //    anyway would make this function slightly harder to think about due
    //    to its relation to Ecliptic's transferPoint().
    //
    require( azimuth.canManage(_point, msg.sender) ||
             ( msg.sender == azimuth.owner() ) );

    Claim[maxClaims] storage currClaims = claims[_point];

    //  clear out all claims
    //
    for (uint8 i = 0; i < maxClaims; i++)
    {
      //  only emit the removed event if there was a claim here
      //
      if ( ( 0 < bytes(currClaims[i].protocol).length ) ||
           ( 0 < bytes(currClaims[i].claim).length ) )
      {
        emit ClaimRemoved(_point, currClaims[i].protocol, currClaims[i].claim);
      }

      delete currClaims[i];
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
    //  we use hashes of the string because solidity can't do string
    //  comparison yet
    //
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
