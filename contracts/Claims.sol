// simple claims store
// draft

pragma solidity 0.4.18;

import './Ships.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Claims is Ownable
{
  event Claimed(uint32 indexed by, string _protocol, string _claim,
                bytes _dossier);
  event Disclaimed(uint32 indexed by, string _protocol, string _claim);

  Ships public ships;

  struct Claim
  {
    string protocol;
    string claim;
    bytes dossier;
  }

  // per ship: claims.
  mapping(uint32 => Claim[]) public claims;
  // per ship: per claim hash: index in claims array (for efficient deletions).
  //NOTE these describe the "nth array element", so they're at index n-1.
  mapping(uint32 => mapping(bytes32 => uint256)) public indices;

  function Claims(Ships _ships)
    public
  {
    ships = _ships;
  }

  function getSampleClaim(string _protocol, string _claim, bytes _dossier)
    pure
    public
    returns (string protocol, string claim, bytes dossier)
  {
    Claim memory clam = Claim(_protocol, _claim, _dossier);
    return (clam.protocol, clam.claim, clam.dossier);
  }

  // since it's currently "not possible to return dynamic content from external
  // function calls" we must expose this as an interface to allow in-contract
  // discoverability of someone's claim count.
  function getClaimCount(uint32 _whose)
    view
    public
    returns (uint256 count)
  {
    return claims[_whose].length;
  }

  function getClaimAtIndex(uint32 _whose, uint256 _index)
    view
    public
    returns (string protocol, string claim, bytes dossier)
  {
    require(_index < claims[_whose].length);
    Claim storage clam = claims[_whose][_index];
    return (clam.protocol, clam.claim, clam.dossier);
  }

  function claim(uint32 _as, string _protocol, string _claim, bytes _dossier)
    external
    pilot(_as)
  {
    require(claims[_as].length < 16);
    bytes32 id = claimId(_protocol, _claim);
    uint256 cur = indices[_as][id];
    if (cur == 0)
    {
      // store a new claim.
      claims[_as].push(Claim(_protocol, _claim, _dossier));
      indices[_as][id] = claims[_as].length;
      Claimed(_as, _protocol, _claim, _dossier);
    }
    else
    {
      // if the claim has already been made, we just update the dossier.
      //NOTE we want to check if the dossier is *actually* changing, but
      //     solidity doesn't allow for comparing (byte)arrays. we could just
      //     hash them and compare that. while keccak256 is cheap, it's still
      //     probably not worth the effort.
      // require(_dossier != claims[_as][cur-1].dossier);
      claims[_as][cur-1] = Claim(_protocol, _claim, _dossier);
    }
  }

  function disclaim(uint32 _as, string _protocol, string _claim)
    external
    pilot(_as)
  {
    bytes32 id = claimId(_protocol, _claim);
    // we delete the target from the list, then fill the gap with the list tail.
    // retrieve current index.
    uint256 i = indices[_as][id];
    require(i > 0);
    i--;
    // copy last item to current index.
    Claim[] storage clams = claims[_as];
    uint256 last = clams.length - 1;
    clams[i] = clams[last];
    // delete last item.
    delete(clams[last]);
    clams.length = last;
    indices[_as][id] = 0;
    Disclaimed(_as, _protocol, _claim);
  }

  function claimId(string _protocol, string _claim)
    pure
    public
    returns (bytes32 id)
  {
    return keccak256(keccak256(_protocol), _claim);
  }

  // test if msg.sender is pilot of _ship.
  modifier pilot(uint32 _ship)
  {
    require(ships.isPilot(_ship, msg.sender));
    _;
  }
}
