//  conditional star release
//  https://azimuth.network

pragma solidity 0.4.24;

import './Ecliptic.sol';
import './TakesPoints.sol';

import './SafeMath16.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

//  ConditionalStarRelease: star transfer over time, based on conditions
//
//    This contract allows its owner to transfer batches of stars to a
//    recipient (also "participant") gradually over time, assuming
//    the specified conditions are met.
//
//    This contract represents a single set of conditions and corresponding
//    deadlines (up to eight) which get configured during contract creation.
//    The conditions take the form of hashes, and they are checked for
//    by looking at the Polls contract. A condition is met if it has
//    achieved a majority in the Polls contract, or its deadline has
//    passed.
//    Completion timestamps are stored for each completed condition.
//    They are equal to the time at which majority was observed, or
//    the condition's deadline, whichever comes first.
//
//    An arbitrary number of participants (in the form of Ethereum
//    addresses) can be registered with the contract.
//    Per participant, the contract stores a commitment. This structure
//    contains the details of the stars to be made available to the
//    participant, configured during registration. This allows for
//    per-participant configuration of the amount of stars they receive
//    per condition, and at what rate these stars get released.
//
//    When a timestamp is set for a condition, the amount of stars in
//    the batch corresponding to that condition is released to the
//    participant at the rate specified in the commitment.
//
//    Stars deposited into the contracts for participants to (eventually)
//    withdraw are treated on a last-in first-out basis.
//
//    If a condition's timestamp is equal to its deadline, participants
//    have the option to forfeit the stars in the associated batch, only
//    if they have not yet withdrawn from that batch. The participant will
//    no longer be able to withdraw stars from the forfeited batch (they are
//    to be collected by the contract owner), and the participant will settle
//    compensation with the contract owner off-chain.
//
//    The contract owner can register commitments, deposit stars into
//    them, and withdraw any stars that got forfeited.
//    Participants can withdraw stars as they get released, and forfeit
//    the remainder of their commitment if a deadline is missed.
//    Anyone can check unsatisfied conditions for completion.
//    If, after a specified date, any stars remain, the owner is able to
//    withdraw them. This saves address space from being lost forever in case
//    of key loss by participants.
//
contract ConditionalStarRelease is Ownable, TakesPoints
{
  using SafeMath for uint256;
  using SafeMath16 for uint16;

  //  ConditionCompleted: :condition has either been met or missed
  //
  event ConditionCompleted(uint8 indexed condition, uint256 when);

  //  Forfeit: :who has chosen to forfeit :batch, which contained
  //           :stars number of stars
  //
  event Forfeit(address indexed who, uint8 batch, uint16 stars);

  //  maxConditions: the max amount of conditions that can be configured
  //
  uint8 constant maxConditions = 8;

  //  conditions: hashes for document proposals that must achieve majority
  //              in the polls contract
  //
  //    a value of 0x0 is special-cased for azimuth initialization logic in
  //    this implementation of the contract
  //
  bytes32[] public conditions;

  //  livelines: dates before which the conditions cannot be registered as met.
  //
  uint256[] public livelines;

  //  deadlines: deadlines by which conditions must have been met. if the
  //             polls contract does not contain a majority vote for the
  //             appropriate condition by the time its deadline is hit,
  //             stars in a commitment can be forfeit and withdrawn by the
  //             CSR contract owner.
  //
  uint256[] public deadlines;

  //  timestamps: timestamps when conditions of the matching index were
  //              hit; or 0 if not yet hit; or equal to the deadline if
  //              the deadline was missed.
  //
  uint256[] public timestamps;

  //  escapeHatchTime: date after which the contract owner can withdraw
  //                   arbitrary stars
  //
  uint256 public escapeHatchDate;

  //  Commitment: structure that mirrors a signed paper contract
  //
  //    While the ordering of the struct members is semantically chaotic,
  //    they are ordered to tightly pack them into Ethereum's 32-byte storage
  //    slots, which reduces gas costs for some function calls.
  //    The comment ticks indicate assumed slot boundaries.
  //
  struct Commitment
  {
    //  stars: specific stars assigned to this commitment that have not yet
    //         been withdrawn
    //
    uint16[] stars;
  //
    //  batches: number of stars to release per condition
    //
    uint16[] batches;
  //
    //  withdrawn: number of stars withdrawn per batch
    //
    uint16[] withdrawn;
  //
    //  forfeited: whether the stars in a batch have been forfeited
    //             by the recipient
    //
    bool[] forfeited;
  //
    //  rateUnit: amount of time it takes for the next :rate stars to be
    //            released
    //
    uint256 rateUnit;
  //
    //  approvedTransferTo: batch can be transferred to this address
    //
    address approvedTransferTo;

    //  total: sum of stars in all batches
    //
    uint16 total;

    //  rate: number of stars released per unlocked batch per :rateUnit
    //
    uint16 rate;
  }

  //  commitments: per participant, the registered purchase agreement
  //
  mapping(address => Commitment) public commitments;

  //  constructor(): configure conditions and deadlines
  //
  constructor( Azimuth _azimuth,
               bytes32[] _conditions,
               uint256[] _livelines,
               uint256[] _deadlines,
               uint256 _escapeHatchDate )
    TakesPoints(_azimuth)
    public
  {
    //  sanity check: limited conditions, liveline and deadline per condition,
    //  and fair escape hatch
    //
    require( _conditions.length > 0 &&
             _conditions.length <= maxConditions &&
             _livelines.length == _conditions.length &&
             _deadlines.length == _conditions.length &&
             _escapeHatchDate > _deadlines[_deadlines.length.sub(1)] );

    //  install conditions and deadlines, and prepare timestamps array
    //
    conditions = _conditions;
    livelines = _livelines;
    deadlines = _deadlines;
    timestamps.length = _conditions.length;
    escapeHatchDate = _escapeHatchDate;

    //  check if the first condition is met, it might get cleared immediately
    //
    analyzeCondition(0);
  }

  //
  //  Functions for the contract owner
  //

    //  register(): register a new commitment
    //
    function register( //  _participant: address of the paper contract signer
                       //  _batches: number of stars releasing per batch
                       //  _rate: number of stars that unlock per _rateUnit
                       //  _rateUnit: amount of time it takes for the next
                       //             _rate stars to unlock
                       //
                       address _participant,
                       uint16[] _batches,
                       uint16 _rate,
                       uint256 _rateUnit )
      external
      onlyOwner
    {
      Commitment storage com = commitments[_participant];

      //  make sure this participant doesn't already have a commitment
      //
      require(0 == com.total);

      //  for every condition/deadline, a batch release amount must be
      //  specified, even if it's zero
      //
      require(_batches.length == conditions.length);

      //  make sure a sane rate is submitted
      //
      require( (_rate > 0) &&
               (_rateUnit > 0) );

      //  make sure we're not promising more than we can possibly give
      //
      uint16 total = arraySum(_batches);
      require( (total > 0) &&
               (total <= 0xff00) );

      //  register into state
      //
      com.batches = _batches;
      com.total = total;
      com.withdrawn.length = _batches.length;
      com.forfeited.length = _batches.length;
      com.rate = _rate;
      com.rateUnit = _rateUnit;
    }

    //  deposit(): deposit a star into this contract for later withdrawal
    //
    function deposit(address _participant, uint16 _star)
      external
      onlyOwner
    {
      Commitment storage com = commitments[_participant];

      //  ensure we can only deposit stars, and that we can't deposit
      //  more stars than necessary
      //
      require( (_star > 0xff) &&
               ( com.stars.length <
                 com.total.sub( arraySum(com.withdrawn) ) ) );

      //  have the contract take ownership of the star if possible,
      //  reverting if that fails.
      //
      require( takePoint(_star, true) );

      //  add _star to the participant's star balance
      //
      com.stars.push(_star);
    }

    //  withdrawForfeited(): withdraw one star, from _participant's forfeited
    //                       _batch, to _to
    //
    function withdrawForfeited(address _participant, uint8 _batch, address _to)
      external
      onlyOwner
    {
      Commitment storage com = commitments[_participant];

      //  withdraw is possible only if the participant has forfeited this batch,
      //  and there's still stars there left to withdraw
      //
      require( com.forfeited[_batch] &&
               (com.withdrawn[_batch] < com.batches[_batch]) &&
               (0 < com.stars.length) );

      //  update contract state
      //
      com.withdrawn[_batch] = com.withdrawn[_batch].add(1);

      //  withdraw a star from the commitment (don't reset it because
      //  no one whom we don't trust has ever had control of it)
      //
      performWithdraw(com, _to, false);
    }

    //  withdrawOverdue(): withdraw arbitrary star from the contract
    //
    //    this functions as an escape hatch in the case of key loss,
    //    to prevent blocks of address space from being lost permanently.
    //
    //    we don't bother with specifying a batch or doing any kind of
    //    book-keeping, because at this point in time we don't care about
    //    that anymore.
    //
    function withdrawOverdue(address _participant, address _to)
      external
      onlyOwner
    {
      //  this can only be done after the :escapeHatchDate
      //
      require(block.timestamp > escapeHatchDate);

      Commitment storage com = commitments[_participant];
      require(0 < com.stars.length);

      //  withdraw a star from the commitment (don't reset it because
      //  no one whom we don't trust has ever had control of it)
      //
      performWithdraw(com, _to, false);
    }

  //
  //  Functions for participants
  //

    //  approveCommitmentTransfer(): allow transfer of the commitment to/by _to
    //
    function approveCommitmentTransfer(address _to)
      external
    {
      //  make sure the caller is a participant,
      //  and that the target isn't
      //
      require( 0 != commitments[msg.sender].total &&
               0 == commitments[_to].total );
      commitments[msg.sender].approvedTransferTo = _to;
    }

    //  transferCommitment(): make an approved transfer of _from's commitment
    //                        to the caller's address
    //
    function transferCommitment(address _from)
      external
    {
      //  make sure the :msg.sender is authorized to make this transfer
      //
      require(commitments[_from].approvedTransferTo == msg.sender);

      //  make sure the target isn't also a participant again,
      //  this could have changed since approveCommitmentTransfer
      //
      require(0 == commitments[msg.sender].total);

      //  copy the commitment to the :msg.sender and clear _from's
      //
      Commitment storage com = commitments[_from];
      commitments[msg.sender] = com;
      delete commitments[_from];
    }

    //  withdrawToSelf(): withdraw one star from the :msg.sender's commitment's
    //                    _batch to :msg.sender
    //
    function withdrawToSelf(uint8 _batch)
      external
    {
      withdraw(_batch, msg.sender);
    }

    //  withdraw(): withdraw one star from the :msg.sender's commitment's
    //              _batch to _to
    //
    function withdraw(uint8 _batch, address _to)
      public
    {
      Commitment storage com = commitments[msg.sender];

      //  to withdraw, the participant must have a star balance,
      //  be under their current withdrawal limit, and cannot
      //  withdraw forfeited stars
      //
      require( (com.stars.length > 0) &&
               (com.withdrawn[_batch] < withdrawLimit(msg.sender, _batch)) &&
               !com.forfeited[_batch] );

      //  update contract state
      //
      com.withdrawn[_batch] = com.withdrawn[_batch].add(1);

      //  withdraw a star from the commitment
      //
      performWithdraw(com, _to, true);
    }

    //  forfeit(): forfeit all stars in the specified _batch, but only if
    //             none have been withdrawn yet
    //
    function forfeit(uint8 _batch)
      external
    {
      Commitment storage com = commitments[msg.sender];

      //  ensure the commitment has actually been configured
      //
      require(0 < com.total);

      //  the participant can forfeit if and only if the condition deadline
      //  is missed (has passed without confirmation), no stars have
      //  been withdrawn from the batch yet, and this batch has not yet
      //  been forfeited
      //
      require( (deadlines[_batch] == timestamps[_batch]) &&
               0 == com.withdrawn[_batch] &&
               !com.forfeited[_batch] );

      //  update commitment metadata
      //
      com.forfeited[_batch] = true;

      //  emit event
      //
      emit Forfeit(msg.sender, _batch, com.batches[_batch]);
    }

  //
  //  Internal functions
  //

    //  performWithdraw(): withdraw a star from _com to _to
    //
    function performWithdraw(Commitment storage _com, address _to, bool _reset)
      internal
    {
      //  star: star to withdraw (from end of array)
      //
      uint16 star = _com.stars[_com.stars.length.sub(1)];

      //  remove the star from the commitment
      //
      _com.stars.length = _com.stars.length.sub(1);

      //  then transfer the star
      //
      require( givePoint(star, _to, _reset) );
    }

  //
  //  Public operations and utilities
  //

    //  analyzeCondition(): analyze condition number _condition for completion;
    //                    set :timestamps[_condition] if either the condition's
    //                    deadline has passed, or its condition has been met
    //
    function analyzeCondition(uint8 _condition)
      public
    {
      //  only analyze conditions that haven't been met yet
      //
      require(0 == timestamps[_condition]);

      //  if the liveline hasn't been passed yet, the condition can't be met
      //
      require(block.timestamp > livelines[_condition]);

      //  if the deadline has passed, the condition is missed, then the
      //  deadline becomes the condition's timestamp
      //
      uint256 deadline = deadlines[_condition];
      if (block.timestamp > deadline)
      {
        timestamps[_condition] = deadline;
        emit ConditionCompleted(_condition, deadline);
        return;
      }

      //  check if the condition has been met
      //
      bytes32 condition = conditions[_condition];
      bool met = false;

      //  if the condition is zero, it is our initialization case
      //
      if (bytes32(0) == condition)
      {
        //  condition is met if the Ecliptic has been upgraded
        //  at least once
        //
        met = (0x0 != Ecliptic(azimuth.owner()).previousEcliptic());
      }
      //
      //  a real condition is met when it has achieved a majority vote
      //
      else
      {
        //  we check using the polls contract from the current ecliptic
        //
        met = Ecliptic(azimuth.owner())
              .polls()
              .documentHasAchievedMajority(condition);
      }

      //  if the condition is met, set :timestamps[_condition] to the
      //  timestamp of the current eth block
      //
      if (met)
      {
        timestamps[_condition] = block.timestamp;
        emit ConditionCompleted(_condition, block.timestamp);
      }
    }

    //  withdrawLimit(): return the number of stars _participant can withdraw
    //                   from _batch at the current block timestamp
    //
    function withdrawLimit(address _participant, uint8 _batch)
      public
      view
      returns (uint16 limit)
    {
      Commitment storage com = commitments[_participant];

      //  if _participant has no commitment, they can't withdraw anything
      //
      if (0 == com.total)
      {
        return 0;
      }

      uint256 ts = timestamps[_batch];

      //  if the condition hasn't completed yet, there is nothing to add.
      //
      if ( ts == 0 )
      {
        limit = 0;
      }
      else
      {
        //  a condition can't have been completed in the future
        //
        assert(ts <= block.timestamp);

        //  calculate the amount of stars available from this batch by
        //  multiplying the release rate (stars per :rateUnit) by the number
        //  of :rateUnits that have passed since the condition completed
        //
        uint256 num = uint256(com.rate).mul(
                      block.timestamp.sub(ts) / com.rateUnit );

        //  bound the release amount by the batch amount
        //
        if ( num > com.batches[_batch] )
        {
          num = com.batches[_batch];
        }

        limit = uint16(num);
      }

      //  allow at least one star, from the first batch that has stars
      //
      if (limit < 1)
      {
        //  first: whether this _batch is the first sequential one to contain
        //         any stars
        //
        bool first = false;

        //  check to see if any batch up to this _batch has stars
        //
        for (uint8 i = 0; i <= _batch; i++)
        {
          //  if this batch has stars, that's the first batch we found
          //
          if (0 < com.batches[i])
          {
            //  maybe it's _batch, but in any case we stop searching here
            //
            first = (i == _batch);
            break;
          }
        }

        if (first)
        {
          return 1;
        }
      }

      return limit;
    }

    //  arraySum(): return the sum of all numbers in _array
    //
    //    only supports sums that fit into a uint16, which is all
    //    this contract needs
    //
    function arraySum(uint16[] _array)
      internal
      pure
      returns (uint16 total)
    {
      for (uint256 i = 0; i < _array.length; i++)
      {
        total = total.add(_array[i]);
      }
      return total;
    }

    //  verifyBalance: check the balance of _participant
    //
    //    Note: for use by clients that have not forfeited,
    //    to verify the contract owner has deposited the stars
    //    they're entitled to.
    //
    function verifyBalance(address _participant)
      external
      view
      returns (bool correct)
    {
      Commitment storage com = commitments[_participant];

      //  return true if this contract holds as many stars as the participant
      //  will ever be entitled to withdraw
      //
      return ( com.stars.length ==
               com.total.sub( arraySum(com.withdrawn) ) );
    }

    //  getBatches(): get the configured batch sizes for a commitment
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getBatches(address _participant)
      external
      view
      returns (uint16[] batches)
    {
      return commitments[_participant].batches;
    }

    //  getBatch(): get the configured size of _batch
    //
    function getBatch(address _participant, uint8 _batch)
      external
      view
      returns (uint16 batch)
    {
      return commitments[_participant].batches[_batch];
    }

    //  getWithdrawn(): get the amounts of stars that have been withdrawn
    //                  from each batch
    //
    function getWithdrawn(address _participant)
      external
      view
      returns (uint16[] withdrawn)
    {
      return commitments[_participant].withdrawn;
    }

    //  getWithdrawnFromBatch(): get the amount of stars that have been
    //                           withdrawn from _batch
    //
    function getWithdrawnFromBatch(address _participant, uint8 _batch)
      external
      view
      returns (uint16 withdrawn)
    {
      return commitments[_participant].withdrawn[_batch];
    }

    //  getForfeited(): for all of _participant's batches, get the forfeit flag
    //
    function getForfeited(address _participant)
      external
      view
      returns (bool[] forfeited)
    {
      return commitments[_participant].forfeited;
    }

    //  getForfeited(): for _participant's _batch, get the forfeit flag
    //
    function hasForfeitedBatch(address _participant, uint8 _batch)
      external
      view
      returns (bool forfeited)
    {
      return commitments[_participant].forfeited[_batch];
    }

    //  getRemainingStars(): get the stars deposited into the commitment
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getRemainingStars(address _participant)
      external
      view
      returns (uint16[] stars)
    {
      return commitments[_participant].stars;
    }

    //  getConditionsState(): get the condition configurations and state
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getConditionsState()
      external
      view
      returns (bytes32[] conds,
               uint256[] lives,
               uint256[] deads,
               uint256[] times)
    {
      return (conditions, livelines, deadlines, timestamps);
    }
}
