// the urbit votes data store
// draft

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import './SafeMath8.sol';

contract Votes is Ownable
{
  using SafeMath8 for uint8;

  event ConcretePollStarted(address proposal);
  event AbstractPollStarted(bytes32 proposal);
  event ConcretePollResult(address proposal, bool passed);
  event AbstractPollResult(bytes32 proposal, bool passed);

  struct Poll
  {
    uint64 start;
    mapping(uint8 => Vote) votes;
    int16 score;
  }

  enum Vote
  {
    Blank,
    Reject,
    Support
  }

  uint64 pollDuration;

  //NOTE we don't need to do the "per current constitution" thing anymore
  //     becauses polls actually close now.
  mapping(address => Poll) public concretePolls;

  mapping(bytes32 => Poll) public abstractPolls;
  // we keep a map for looking up if a proposal ever achieved majority.
  mapping(bytes32 => bool) public abstractMajorityMap;
  // we store an append-only list of proposals that have achieved majority.
  bytes32[] public abstractMajorities;

  function Votes(uint64 _pollDuration)
    public
  {
    pollDuration = _pollDuration;
  }

  function changePollDuration(uint64 _duration)
    public
    onlyOwner
  {
    pollDuration = _duration;
  }

  function startConcretePoll(address _proposal)
    external
    onlyOwner
  {
    Poll storage poll = concretePolls[_proposal];
    require(poll.start == 0);
    poll.start = block.timestamp;
    ConcretePollStarted(_proposal);
  }

  function startAbstractPoll(bytes32 _proposal)
    external
    onlyOwner
  {
    Poll storage poll = abstractPolls[_proposal];
    require(poll.start == 0);
    poll.start = block.timestamp;
    AbstractPollStarted(_proposal);
  }

  function castConcreteVote(uint8 _as, address _proposal, Vote _vote)
    external
    onlyOwner
  {
    Poll storage poll = concretePolls[_proposal];
    require((poll.start + pollDuration) < block.timestamp);
    Vote storage oldVote = poll.votes[_as];
    //TODO maybe require vote to be different from stored vote.
    int8 calcOldVote = getVoteValue(poll.votes[_as]);
    int8 calcNewVote = getVoteValue(_vote);
    // pretty sure the math here checks out.
    poll.score = poll.score + (calcNewVote - calcOldVote);
    poll.votes[_as] = _vote;
  }

  function castAbstractVote(uint8 _as, bytes32 _proposal, Vote _vote)
    external
    onlyOwner
  {
    Poll storage poll = abstractPolls[_proposal];
    //TODO we can't pass references into internal functions, can we?
    //     because all code below is identical to the concrete case
    require((poll.start + pollDuration) < block.timestamp);
    Vote storage oldVote = poll.votes[_as];
    //TODO maybe require vote to be different from stored vote.
    int8 calcOldVote = getVoteValue(poll.votes[_as]);
    int8 calcNewVote = getVoteValue(_vote);
    // pretty sure the math here checks out.
    poll.score = poll.score + (calcNewVote - calcOldVote);
    poll.votes[_as] = _vote;
  }

  function endConcretePoll(address _proposal)
    external
    onlyOwner
    returns (bool majority)
  {
    Poll storage poll = concretePolls[_proposal];
    require((poll.start + pollDuration) > block.timestamp);
    //TODO how do we want to deal with ties?
    bool majority = (poll.votes > 0);
    ConcretePollResult(_proposal, majority);
    return majority;
  }

  function endAbstractPoll(address _proposal)
    external
    onlyOwner
  {
    Poll storage poll = concretePolls[_proposal];
    require((poll.start + pollDuration) > block.timestamp);
    //TODO how do we want to deal with ties?
    bool majority = (poll.votes > 0);
    if (majority)
    {
      abstractMajorityMap[_proposal] = true;
      abstractMajorities.push(_proposal);
    }
    AbstractPollResult(_proposal, majority);
  }

  // for score diff calculations.
  // we can't do fun enum math here, that's uint and we need 0 to be blank.
  function getVoteValue(Vote _vote)
    internal
    returns (int8 value)
  {
         if (_vote == Reject)  return -1;
    else if (_vote == Blank)   return  0;
    else if (_vote == Support) return  1;
  }
}
