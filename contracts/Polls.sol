//  the urbit polls data store

pragma solidity 0.4.24;

import './SafeMath8.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

//  Polls: proposals & votes data contract
//
//    This contract is used for storing all data related to the proposals
//    of the senate (galaxy owners) and their votes on those proposals.
//    It keeps track of votes and uses them to calculate whether a majority
//    is in favor of a proposal.
//
//    Since data stores are difficult to upgrade, all of the logic unrelated
//    to the voting itself (that is, determining who is eligible to vote)
//    is expected to be implemented by this contract's owner.
//
//    Initially, this contract will be owned by the Constitution contract.
//
contract Polls is Ownable
{
  //  ConcretePollStarted: a poll on :proposal has opened
  //
  event ConcretePollStarted(address proposal);

  //  AbstractPollStarted: a poll on :proposal has opened
  //
  event AbstractPollStarted(bytes32 proposal);

  //  ConcreteMajority: :proposal has achieved majority
  //
  event ConcreteMajority(address proposal);

  //  AbstractMajority: :proposal has achieved majority
  //
  event AbstractMajority(bytes32 proposal);

  //  Poll: full poll state
  //
  struct Poll
  {
    //  start: the timestamp at which the poll was started
    //
    uint256 start;

    //  voted: per galaxy, whether they have voted on this poll
    //
    bool[256] voted;

    //  yesVotes: amount of votes in favor of the proposal
    //
    uint8 yesVotes;

    //  noVotes: amount of votes against the proposal
    //
    uint8 noVotes;
  }

  //  pollDuration: amount of time during which a poll can be voted on
  //
  uint256 public pollDuration;

  //  pollCooldown: amount of time before a non-majority poll can be reopened
  //
  uint256 public pollCooldown;

  //  totalVoters: amount of active galaxies
  //
  uint8 public totalVoters;

  //  concretePolls: per address, poll held to determine if that address
  //                 will become the new constitution
  //
  mapping(address => Poll) public concretePolls;

  //  concreteMajorityMap: per address, whether that address has ever
  //                       achieved majority
  //
  //    if we did not store this, we would have to look at old poll data
  //    to see whether or not a proposal has achieved majority. but since
  //    the results calculated from poll data rely on contract configuration
  //    that may not be accurate accross time. by storing majority flags
  //    explicitly, we can always tell with certainty whether or not a
  //    majority was achieved.
  //
  mapping(address => bool) public concreteMajorityMap;

  //  abstractPolls: per hash, poll held to determine if the corresponding
  //                 document is accepted by the galactic senate
  //
  mapping(bytes32 => Poll) public abstractPolls;

  //  abstractMajorityMap: per hash, whether that hash has ever
  //                       achieved majority
  //
  //    the note for concreteMajorityMap above applies here as well
  //
  mapping(bytes32 => bool) public abstractMajorityMap;

  //  abstractMajorities: all hashes that have achieved majority
  //
  bytes32[] public abstractMajorities;

  //  constructor(): initial contract configuration
  //
  constructor(uint256 _pollDuration, uint256 _pollCooldown)
    public
  {
    reconfigure(_pollDuration, _pollCooldown);
  }

  //  reconfigure(): change poll duration, cooldown, and vote requirements
  //
  function reconfigure(uint256 _pollDuration, uint256 _pollCooldown)
    public
    onlyOwner
  {
    pollDuration = _pollDuration;
    pollCooldown = _pollCooldown;
  }

  //  incrementTotalVoters(): increase the amount of registered voters
  //
  function incrementTotalVoters()
    external
    onlyOwner
  {
    require(totalVoters < 255);
    totalVoters = totalVoters + 1;
  }

  //  getAbstractMajorities(): return array of all abstract majorities
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getAbstractMajorities()
    external
    view
    returns (bytes32[] majorities)
  {
    return abstractMajorities;
  }

  //  hasVotedOnConcretePoll(): returns true if _who has voted on the _proposal
  //
  function hasVotedOnConcretePoll(uint8 _who, address _proposal)
    external
    view
    returns (bool result)
  {
    Poll storage poll = concretePolls[_proposal];
    return hasVoted(_who, poll);
  }

  //  hasVotedOnAbstractPoll(): returns true if _who has voted on the _proposal
  //
  function hasVotedOnAbstractPoll(uint8 _who, bytes32 _proposal)
    external
    view
    returns (bool result)
  {
    Poll storage poll = abstractPolls[_proposal];
    return hasVoted(_who, poll);
  }

  //  hasVoted(): returns true if _who has voted on the _poll
  //
  function hasVoted(uint8 _who, Poll storage _poll)
    internal
    view
    returns (bool result)
  {
    return _poll.voted[_who];
  }

  //  startConretePoll(): open a poll on making _proposal the new constitution
  //
  function startConcretePoll(address _proposal)
    external
    onlyOwner
  {
    //  _proposal must not have achieved majority before
    //
    require(!concreteMajorityMap[_proposal]);

    //  start the poll
    //
    Poll storage poll = concretePolls[_proposal];
    startPoll(poll);
    emit ConcretePollStarted(_proposal);
  }

  //  startAbstractPoll(): open a poll on accepting the document
  //                       whose hash is _proposal
  //
  function startAbstractPoll(bytes32 _proposal)
    external
    onlyOwner
  {
    //  _proposal must not have achieved majority before
    //
    require(!abstractMajorityMap[_proposal]);

    //  start the poll
    //
    Poll storage poll = abstractPolls[_proposal];
    startPoll(poll);
    emit AbstractPollStarted(_proposal);
  }

  //  startPoll(): open a new poll, or re-open an old one
  //
  function startPoll(Poll storage _poll)
    internal
  {
    //  check that the poll has cooled down enough to be started again
    //
    //    for completely new polls, :start will be zero, so this check
    //    will only fail for unreasonable duration and cooldown values
    //
    require(block.timestamp > (_poll.start + pollDuration + pollCooldown));

    //  set started poll state
    //
    _poll.start = block.timestamp;
    delete _poll.voted;
    _poll.yesVotes = 0;
    _poll.noVotes = 0;
  }

  //  castConcreteVote(): as galaxy _as, cast a vote on the _proposal
  //
  //    _vote is true when in favor of the proposal, false otherwise
  //
  function castConcreteVote(uint8 _as, address _proposal, bool _vote)
    external
    onlyOwner
    returns (bool majority)
  {
    Poll storage poll = concretePolls[_proposal];
    processVote(poll, _as, _vote);
    return updateConcretePoll(_proposal);
  }

  //  castAbstractVote(): as galaxy _as, cast a vote on the _proposal
  //
  //    _vote is true when in favor of the proposal, false otherwise
  //
  function castAbstractVote(uint8 _as, bytes32 _proposal, bool _vote)
    external
    onlyOwner
  {
    Poll storage poll = abstractPolls[_proposal];
    processVote(poll, _as, _vote);
    updateAbstractPoll(_proposal);
  }

  //  processVote(): record a vote from _as on the _poll
  //
  function processVote(Poll storage _poll, uint8 _as, bool _vote)
    internal
  {
    require( //  may only vote once
             //
             !_poll.voted[_as] &&
             //
             //  may only vote when the poll is open
             //
             (block.timestamp < (_poll.start + pollDuration)) );

    //  update poll state to account for the new vote
    //
    _poll.voted[_as] = true;
    if (_vote)
    {
      _poll.yesVotes = _poll.yesVotes + 1;
    }
    else
    {
      _poll.noVotes = _poll.noVotes + 1;
    }
  }

  //  updateConcretePoll(): check whether the _proposal has achieved majority,
  //                        updating state, sending an event, and returning
  //                        true if it has
  //
  function updateConcretePoll(address _proposal)
    public
    onlyOwner
    returns (bool majority)
  {
    //  _proposal must not have achieved majority before
    //
    require(!concreteMajorityMap[_proposal]);

    //  check for majority in the poll
    //
    Poll storage poll = concretePolls[_proposal];
    majority = checkPollMajority(poll);

    //  if majority was achieved, update the state and send an event
    //
    if (majority)
    {
      concreteMajorityMap[_proposal] = true;
      emit ConcreteMajority(_proposal);
    }
  }

  //  updateAbstractPoll(): check whether the _proposal has achieved majority,
  //                        updating the state and sending an event if it has
  //
  //    this can be called by anyone, because the constitution does not
  //    need to be aware of the result
  //
  function updateAbstractPoll(bytes32 _proposal)
    public
  {
    //  _proposal must not have achieved majority before
    //
    require(!abstractMajorityMap[_proposal]);

    //  check for majority in the poll
    //
    Poll storage poll = abstractPolls[_proposal];
    bool majority = checkPollMajority(poll);

    //  if majority was achieved, update state and send an event
    //
    if (majority)
    {
      abstractMajorityMap[_proposal] = true;
      abstractMajorities.push(_proposal);
      emit AbstractMajority(_proposal);
    }
  }

  //  checkPollMajority(): returns true if the majority is in favor of
  //                       the subject of the poll
  //
  function checkPollMajority(Poll _poll)
    internal
    view
    returns (bool majority)
  {
    return ( //  poll must have at least the minimum required yes-votes
             //
             (_poll.yesVotes >= (totalVoters / 4)) &&
             //
             //  and have a majority...
             //
             (_poll.yesVotes > _poll.noVotes) &&
             //
             //  ...that is indisputable
             //
             ( //  either because the poll has ended
               //
               (block.timestamp > (_poll.start + pollDuration)) ||
               //
               //  or because there aren't enough remaining voters to
               //  tip the scale
               //
               ( (_poll.yesVotes - _poll.noVotes) >
                 (totalVoters - (_poll.yesVotes + _poll.noVotes)) ) ) );
  }
}
