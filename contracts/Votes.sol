// the urbit votes data store
// untested draft

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Votes is Ownable
{
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
    totalVoters = totalVoters + 1;
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
  function castVote(uint8 _galaxy, address _proposal, bool _vote)
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
    // update the vote.
    concreteVotes[owner][_proposal][_galaxy] = _vote;
    uint8 oldCount = concreteVoteCounts[owner][_proposal];
    // when voting yes,
    if (_vote)
    {
      // increment the proposal's vote count.
      uint8 newCount = oldCount + 1;
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
      concreteVoteCounts[owner][_proposal] = oldCount - 1;
    }
  }

  // vote on an abstract proposal.
  //TODO doing wasMajority is sensitive to people un-voting and re-voting.
  //     depending on whether or not we want to be able to get a list of
  //     supported hashes, we either use a mapping or a construction similar
  //     to ship's pilots.
  function castVote(uint8 _galaxy, bytes32 _proposal, bool _vote)
    external
    onlyOwner
  {
    bool prev = abstractVotes[_proposal][_galaxy];
    // vote must differ from what is already registered, to discourage
    // unnecessary work.
    require(prev != _vote);
    abstractVotes[_proposal][_galaxy] = _vote;
    // when voting yes,
    if (_vote)
    {
      uint8 oldCount = abstractVoteCounts[_proposal];
      bool wasMajority = oldCount > totalVoters / 2;
      abstractVoteCounts[_proposal] = oldCount + 1;
      // if the proposal just became a majority, add it to the list.
      if (!wasMajority && oldCount + 1 > totalVoters / 2)
      {
        abstractMajorities.push(_proposal);
        AbstractMajority(_proposal);
      }
    // when voting no, simply decrement the proposal's vote count.
    } else {
      abstractVoteCounts[_proposal] = abstractVoteCounts[_proposal] - 1;
    }
  }
}
