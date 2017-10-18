// the urbit votes data store
// untested draft

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import './SafeMath8.sol';

contract Votes is Ownable
{
  using SafeMath8 for uint8;

  event ConcreteMajority(address constitution);
  event AbstractMajority(bytes32 hash);

  // we depend on the constitution to tell us how many voters there are, so that
  // we can determine how many votes are necessary for a majority.
  uint8 public totalVoters;

  // for concrete votes, we keep track of them *per constitution*, so that votes
  // from a "previous era" can't take effect when an upgrade has already
  // happened. this prevents issues with incompatible constitutions.

  // per constitution, we keep track of the votes for each proposed address.
  // we use these to determine whether a vote gets added or retracted.
  mapping(address => mapping(address => bool[256])) private concreteVotes;
  // we also keep track of vote counts per proposed address.
  // we use these to determine majorities.
  mapping(address => mapping(address => uint8)) public concreteVoteCounts;

  // for abstract votes, we do the same:
  // keep track of individual votes,
  mapping(bytes32 => bool[256]) private abstractVotes;
  // and total counts.
  mapping(bytes32 => uint8) public abstractVoteCounts;
  // we keep a map for looking up if a proposal ever achieved majority.
  mapping(bytes32 => bool) public abstractMajorityMap;
  // we store an append-only list of proposals that have achieved majority.
  bytes32[] public abstractMajorities;

  function Votes()
  {
    //
  }

  // to be called by the constitution whenever appropriate.
  // (whenever a galaxy becomes living.)
  function incrementTotalVoters()
    external
    onlyOwner
  {
    require(totalVoters < 255);
    totalVoters++;
  }

  // we provide these getter functions so that clients can easily check if their
  // would-be vote actually differs from their currently registered one.

  function getVote(uint8 _galaxy, address _proposal)
    external
    constant
    returns(bool vote)
  {
    return concreteVotes[owner][_proposal][_galaxy];
  }

  function getVote(uint8 _galaxy, bytes32 _proposal)
    external
    constant
    returns(bool vote)
  {
    return abstractVotes[_proposal][_galaxy];
  }

  function getAbstractMajorities()
    external
    constant
    returns (bytes32[] majorities)
  {
    return abstractMajorities;
  }

  // ++vot
  // voting for change

  // vote on a concrete proposal.
  function castConcreteVote(uint8 _galaxy, address _proposal, bool _vote)
    external
    onlyOwner
    returns(bool newMajority)
  {
    // can't vote for the currently active constitution.
    require(_proposal != owner);
    bool prev = concreteVotes[owner][_proposal][_galaxy];
    // vote must differ from what is already registered, to discourage
    // unnecessary work.
    require(prev != _vote);
    concreteVotes[owner][_proposal][_galaxy] = _vote;
    uint8 oldCount = concreteVoteCounts[owner][_proposal];
    // when voting yes,
    if (_vote)
    {
      // increment the proposal's vote count.
      uint8 newCount = oldCount.add(1);
      concreteVoteCounts[owner][_proposal] = newCount;
      // if that makes it a majority vote, return true to notify the
      // constitution.
      if (newCount > totalVoters / 2)
      {
        ConcreteMajority(_proposal);
        return true;
      } else {
        return false;
      }
    // when voting no, simply decrement the proposal's vote count.
    } else {
      concreteVoteCounts[owner][_proposal] = oldCount.sub(1);
    }
  }

  // vote on an abstract proposal.
  function castAbstractVote(uint8 _galaxy, bytes32 _proposal, bool _vote)
    external
    onlyOwner
  {
    // once a proposal has achieved majority, we freeze votes on it.
    require(!abstractMajorityMap[_proposal]);
    bool prev = abstractVotes[_proposal][_galaxy];
    // vote must differ from what is already registered, to discourage
    // unnecessary work.
    require(prev != _vote);
    abstractVotes[_proposal][_galaxy] = _vote;
    uint8 oldCount = abstractVoteCounts[_proposal];
    // when voting yes,
    if (_vote)
    {
      // increment the proposal's vote count.
      uint8 newCount = oldCount.add(1);
      abstractVoteCounts[_proposal] = newCount;
      // if that makes it a majority vote, append it to the list.
      if (newCount > totalVoters / 2)
      {
        abstractMajorityMap[_proposal] = true;
        abstractMajorities.push(_proposal);
        AbstractMajority(_proposal);
      }
    // when voting no, simply decrement the proposal's vote count.
    } else {
      abstractVoteCounts[_proposal] = oldCount.sub(1);
    }
  }
}
