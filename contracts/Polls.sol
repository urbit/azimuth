//  the azimuth polls data store

pragma solidity 0.4.24;

import './SafeMath8.sol';
import './SafeMath16.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

//  Polls: proposals & votes data contract
//
//    This contract is used for storing all data related to the proposals
//    of the senate (galaxy owners) and their votes on those proposals.
//    It keeps track of votes and uses them to calculate whether a majority
//    is in favor of a proposal.
//
//    Every galaxy can only vote on a proposal exactly once. Votes cannot
//    be changed. If a proposal fails to achieve majority within its
//    duration, it can be restarted after its cooldown period has passed.
//
//    The requirements for a proposal to achieve majority are as follows:
//    - At least 1/4 of the currently active voters (rounded down) must have
//      voted in favor of the proposal,
//    - More than half of the votes cast must be in favor of the proposal,
//      and this can no longer change, either because
//      - the poll duration has passed, or
//      - not enough voters remain to take away the in-favor majority.
//    As soon as these conditions are met, no further interaction with
//    the proposal is possible. Achieving majority is permanent.
//
//    Since data stores are difficult to upgrade, all of the logic unrelated
//    to the voting itself (that is, determining who is eligible to vote)
//    is expected to be implemented by this contract's owner.
//
//    This contract will be owned by the Ecliptic contract.
//
contract Polls is Ownable
{
  using SafeMath for uint256;
  using SafeMath16 for uint16;
  using SafeMath8 for uint8;

  //  UpgradePollStarted: a poll on :proposal has opened
  //
  event UpgradePollStarted(address proposal);

  //  DocumentPollStarted: a poll on :proposal has opened
  //
  event DocumentPollStarted(bytes32 proposal);

  //  UpgradeMajority: :proposal has achieved majority
  //
  event UpgradeMajority(address proposal);

  //  DocumentMajority: :proposal has achieved majority
  //
  event DocumentMajority(bytes32 proposal);

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
    uint16 yesVotes;

    //  noVotes: amount of votes against the proposal
    //
    uint16 noVotes;

    //  duration: amount of time during which the poll can be voted on
    //
    uint256 duration;

    //  cooldown: amount of time before the (non-majority) poll can be reopened
    //
    uint256 cooldown;
  }

  //  pollDuration: duration set for new polls. see also Poll.duration above
  //
  uint256 public pollDuration;

  //  pollCooldown: cooldown set for new polls. see also Poll.cooldown above
  //
  uint256 public pollCooldown;

  //  totalVoters: amount of active galaxies
  //
  uint16 public totalVoters;

  //  upgradeProposals: list of all upgrades ever proposed
  //
  //    this allows clients to discover the existence of polls.
  //    from there, they can do liveness checks on the polls themselves.
  //
  address[] public upgradeProposals;

  //  upgradePolls: per address, poll held to determine if that address
  //                will become the new ecliptic
  //
  mapping(address => Poll) public upgradePolls;

  //  upgradeHasAchievedMajority: per address, whether that address
  //                              has ever achieved majority
  //
  //    if we did not store this, we would have to look at old poll data
  //    to see whether or not a proposal has ever achieved majority.
  //    since the outcome of a poll is calculated based on :totalVoters,
  //    which may not be consistent accross time, we need to store outcomes
  //    explicitly instead of re-calculating them, so that we can always
  //    tell with certainty whether or not a majority was achieved,
  //    regardless of the current :totalVoters.
  //
  mapping(address => bool) public upgradeHasAchievedMajority;

  //  documentProposals: list of all documents ever proposed
  //
  //    this allows clients to discover the existence of polls.
  //    from there, they can do liveness checks on the polls themselves.
  //
  bytes32[] public documentProposals;

  //  documentPolls: per hash, poll held to determine if the corresponding
  //                 document is accepted by the galactic senate
  //
  mapping(bytes32 => Poll) public documentPolls;

  //  documentHasAchievedMajority: per hash, whether that hash has ever
  //                               achieved majority
  //
  //    the note for upgradeHasAchievedMajority above applies here as well
  //
  mapping(bytes32 => bool) public documentHasAchievedMajority;

  //  documentMajorities: all hashes that have achieved majority
  //
  bytes32[] public documentMajorities;

  //  constructor(): initial contract configuration
  //
  constructor(uint256 _pollDuration, uint256 _pollCooldown)
    public
  {
    reconfigure(_pollDuration, _pollCooldown);
  }

  //  reconfigure(): change poll duration and cooldown
  //
  function reconfigure(uint256 _pollDuration, uint256 _pollCooldown)
    public
    onlyOwner
  {
    require( (5 days <= _pollDuration) && (_pollDuration <= 90 days) &&
             (5 days <= _pollCooldown) && (_pollCooldown <= 90 days) );
    pollDuration = _pollDuration;
    pollCooldown = _pollCooldown;
  }

  //  incrementTotalVoters(): increase the amount of registered voters
  //
  function incrementTotalVoters()
    external
    onlyOwner
  {
    require(totalVoters < 256);
    totalVoters = totalVoters.add(1);
  }

  //  getAllUpgradeProposals(): return array of all upgrade proposals ever made
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getUpgradeProposals()
    external
    view
    returns (address[] proposals)
  {
    return upgradeProposals;
  }

  //  getUpgradeProposalCount(): get the number of unique proposed upgrades
  //
  function getUpgradeProposalCount()
    external
    view
    returns (uint256 count)
  {
    return upgradeProposals.length;
  }

  //  getAllDocumentProposals(): return array of all upgrade proposals ever made
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getDocumentProposals()
    external
    view
    returns (bytes32[] proposals)
  {
    return documentProposals;
  }

  //  getDocumentProposalCount(): get the number of unique proposed upgrades
  //
  function getDocumentProposalCount()
    external
    view
    returns (uint256 count)
  {
    return documentProposals.length;
  }

  //  getDocumentMajorities(): return array of all document majorities
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getDocumentMajorities()
    external
    view
    returns (bytes32[] majorities)
  {
    return documentMajorities;
  }

  //  hasVotedOnUpgradePoll(): returns true if _galaxy has voted
  //                           on the _proposal
  //
  function hasVotedOnUpgradePoll(uint8 _galaxy, address _proposal)
    external
    view
    returns (bool result)
  {
    return upgradePolls[_proposal].voted[_galaxy];
  }

  //  hasVotedOnDocumentPoll(): returns true if _galaxy has voted
  //                            on the _proposal
  //
  function hasVotedOnDocumentPoll(uint8 _galaxy, bytes32 _proposal)
    external
    view
    returns (bool result)
  {
    return documentPolls[_proposal].voted[_galaxy];
  }

  //  startUpgradePoll(): open a poll on making _proposal the new ecliptic
  //
  function startUpgradePoll(address _proposal)
    external
    onlyOwner
  {
    //  _proposal must not have achieved majority before
    //
    require(!upgradeHasAchievedMajority[_proposal]);

    Poll storage poll = upgradePolls[_proposal];

    //  if the proposal is being made for the first time, register it.
    //
    if (0 == poll.start)
    {
      upgradeProposals.push(_proposal);
    }

    startPoll(poll);
    emit UpgradePollStarted(_proposal);
  }

  //  startDocumentPoll(): open a poll on accepting the document
  //                       whose hash is _proposal
  //
  function startDocumentPoll(bytes32 _proposal)
    external
    onlyOwner
  {
    //  _proposal must not have achieved majority before
    //
    require(!documentHasAchievedMajority[_proposal]);

    Poll storage poll = documentPolls[_proposal];

    //  if the proposal is being made for the first time, register it.
    //
    if (0 == poll.start)
    {
      documentProposals.push(_proposal);
    }

    startPoll(poll);
    emit DocumentPollStarted(_proposal);
  }

  //  startPoll(): open a new poll, or re-open an old one
  //
  function startPoll(Poll storage _poll)
    internal
  {
    //  check that the poll has cooled down enough to be started again
    //
    //    for completely new polls, the values used will be zero
    //
    require( block.timestamp > ( _poll.start.add(
                                 _poll.duration.add(
                                 _poll.cooldown )) ) );

    //  set started poll state
    //
    _poll.start = block.timestamp;
    delete _poll.voted;
    _poll.yesVotes = 0;
    _poll.noVotes = 0;
    _poll.duration = pollDuration;
    _poll.cooldown = pollCooldown;
  }

  //  castUpgradeVote(): as galaxy _as, cast a vote on the _proposal
  //
  //    _vote is true when in favor of the proposal, false otherwise
  //
  function castUpgradeVote(uint8 _as, address _proposal, bool _vote)
    external
    onlyOwner
    returns (bool majority)
  {
    Poll storage poll = upgradePolls[_proposal];
    processVote(poll, _as, _vote);
    return updateUpgradePoll(_proposal);
  }

  //  castDocumentVote(): as galaxy _as, cast a vote on the _proposal
  //
  //    _vote is true when in favor of the proposal, false otherwise
  //
  function castDocumentVote(uint8 _as, bytes32 _proposal, bool _vote)
    external
    onlyOwner
    returns (bool majority)
  {
    Poll storage poll = documentPolls[_proposal];
    processVote(poll, _as, _vote);
    return updateDocumentPoll(_proposal);
  }

  //  processVote(): record a vote from _as on the _poll
  //
  function processVote(Poll storage _poll, uint8 _as, bool _vote)
    internal
  {
    //  assist symbolic execution tools
    //
    assert(block.timestamp >= _poll.start);

    require( //  may only vote once
             //
             !_poll.voted[_as] &&
             //
             //  may only vote when the poll is open
             //
             (block.timestamp < _poll.start.add(_poll.duration)) );

    //  update poll state to account for the new vote
    //
    _poll.voted[_as] = true;
    if (_vote)
    {
      _poll.yesVotes = _poll.yesVotes.add(1);
    }
    else
    {
      _poll.noVotes = _poll.noVotes.add(1);
    }
  }

  //  updateUpgradePoll(): check whether the _proposal has achieved
  //                            majority, updating state, sending an event,
  //                            and returning true if it has
  //
  function updateUpgradePoll(address _proposal)
    public
    onlyOwner
    returns (bool majority)
  {
    //  _proposal must not have achieved majority before
    //
    require(!upgradeHasAchievedMajority[_proposal]);

    //  check for majority in the poll
    //
    Poll storage poll = upgradePolls[_proposal];
    majority = checkPollMajority(poll);

    //  if majority was achieved, update the state and send an event
    //
    if (majority)
    {
      upgradeHasAchievedMajority[_proposal] = true;
      emit UpgradeMajority(_proposal);
    }
    return majority;
  }

  //  updateDocumentPoll(): check whether the _proposal has achieved majority,
  //                        updating the state and sending an event if it has
  //
  //    this can be called by anyone, because the ecliptic does not
  //    need to be aware of the result
  //
  function updateDocumentPoll(bytes32 _proposal)
    public
    returns (bool majority)
  {
    //  _proposal must not have achieved majority before
    //
    require(!documentHasAchievedMajority[_proposal]);

    //  check for majority in the poll
    //
    Poll storage poll = documentPolls[_proposal];
    majority = checkPollMajority(poll);

    //  if majority was achieved, update state and send an event
    //
    if (majority)
    {
      documentHasAchievedMajority[_proposal] = true;
      documentMajorities.push(_proposal);
      emit DocumentMajority(_proposal);
    }
    return majority;
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
               (block.timestamp > _poll.start.add(_poll.duration)) ||
               //
               //  or because there aren't enough remaining voters to
               //  tip the scale
               //  "score" is greater than "remaining votes"
               //
               ( _poll.yesVotes.sub(_poll.noVotes) >
                 totalVoters.sub( _poll.yesVotes.add(_poll.noVotes) ) ) ) );
  }
}
