//  conditional star release

pragma solidity 0.4.24;

import './Constitution.sol';
import './SafeMath16.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

//  ConditionalStarRelease: star transfer over time, based on conditions
//
//    This contract allows its owner to transfer batches of stars to a
//    recipient (also "participant") gradually over time, assuming
//    the specified conditions are met.
//
//    This contract represents a single set of conditions and corrosponding
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
//    When a timestamp for a condition is set, the amount of stars in
//    the batch corresponding to that condition is released to the
//    participant at the rate specified in the commitment.
//
//    Stars deposited into the contracts for participants to (eventually)
//    withdraw are treated on a last-in first-out basis.
//
//    If a condition's timestamp is equal to its deadline, participants
//    have the option to forfeit any stars that remain in their commitment
//    from that condition's batch and onward. The participant will no
//    longer be able to withdraw any of the forfeited stars (they are to
//    be collected by the contract owner), and will settle compensation
//    with the contract owner off-chain.
//
//    The contract owner can register commitments, deposit stars into
//    them, and withdraw any stars that got forfeited.
//    Participants can withdraw stars as they get released, and forfeit
//    the remainder of their commitment if a deadline is missed.
//    Anyone can check unsatisfied conditions for completion.
//    If, ten years after the first condition completes (usually equivalent
//    to contract launch), any stars remain, the owner is able to withdraw
//    them. This saves address space from being lost forever in case of
//    key loss by participants.
//
contract ConditionalStarRelease is Ownable
{
  using SafeMath for uint256;
  using SafeMath16 for uint16;

  //  ConditionCompleted: :condition has either been met or missed
  //
  event ConditionCompleted(uint8 indexed condition, uint256 when);

  //  Forfeit: :who has chosen to forfeit :stars number of stars
  //
  event Forfeit(address indexed who, uint16 stars);

  //  maxConditions: the max amount of conditions that can be configured
  //  escapeHatchTime: amount of time after the first condition completes, after
  //                   which the contract owner can withdraw arbitrary stars
  //
  uint8 constant maxConditions = 8;
  uint256 constant escapeHatchTime = 10 * 365 days;

  //  ships: public contract which stores ship state
  //  polls: public contract which registers polls
  //
  Ships public ships;
  Polls public polls;

  //  conditions: hashes for document proposals that must achieve majority
  //              in the polls contract
  //
  bytes32[] public conditions;

  //  deadlines: deadlines by which conditions must have been met. if the
  //             polls contract does not contain a majority vote for the
  //             appropriate condition by the time its deadline is hit,
  //             stars in a commitment can be forfeit and withdrawn by the
  //             CSR contract owner.
  //
  uint256[] public deadlines;

  //  timestamps: timestamps when deadlines of the matching index were
  //              hit; or 0 if not yet hit; or equal to the deadline if
  //              the deadline was missed.
  //
  uint256[] public timestamps;

  //  Commitment: structure that mirrors a signed paper contract
  //
  struct Commitment
  {
    //  batches: number of stars to release per condition
    //
    uint16[] batches;

    //  total: sum of stars in all batches
    //
    uint16 total;

    //  rate: number of stars released per unlocked batch per :rateUnit
    //
    uint16 rate;

    //  rateUnit: amount of time it takes for the next :rate stars to be
    //            released
    //
    uint256 rateUnit;

    //  stars: specific stars assigned to this commitment that have not yet
    //         been withdrawn
    //
    uint16[] stars;

    //  withdrawn: number of stars withdrawn by the participant
    //
    uint16 withdrawn;

    //  forfeit: true if this commitment has forfeited any future stars
    //
    bool forfeit;

    //  forfeited: number of forfeited stars not yet withdrawn by
    //             the contract owner
    //
    uint16 forfeited;
  }

  //  commitments: per participant, the registered purchase agreement
  //
  mapping(address => Commitment) public commitments;

  //  transfers: per participant, the approved commitment transfer
  //
  mapping(address => address) public transfers;

  //  constructor(): configure conditions and deadlines
  //
  constructor(Ships _ships, bytes32[] _conditions, uint256[] _deadlines)
    public
  {
    //  sanity check: condition per deadline
    //
    require( _conditions.length > 0 &&
             _conditions.length <= maxConditions &&
             _deadlines.length == _conditions.length );

    //  reference ships and polls contracts
    //
    ships = _ships;
    polls = Constitution(ships.owner()).polls();

    //  install conditions and deadlines, and prepare timestamps array
    //
    conditions = _conditions;
    deadlines = _deadlines;
    timestamps.length = _deadlines.length;

    //  check if the first condition is met. most uses of this contract
    //  will set its condition to 0, clearing it immediately
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
      //  for every condition/deadline, a batch release amount must be
      //  specified, even if it's zero
      //
      require(_batches.length == conditions.length);

      //  make sure a sane rate is submitted
      //
      require(_rate > 0);

      //  make sure we're not promising more than we can possibly give
      //
      uint16 total = totalStars(_batches, 0);
      require(com.total <= 65280);

      Commitment storage com = commitments[_participant];
      com.batches = _batches;
      com.total = total;
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
      require( (_star > 255) &&
               ( com.stars.length <
                 com.total.sub( com.withdrawn.add(com.forfeited) ) ) );

      //  There are two ways to deposit a star.  One way is for a galaxy to
      //  grant the CSR contract permission to spawn its stars.  The CSR
      //  contract will spawn the star directly to itself.
      //
      //  The CSR contract can also accept existing stars, as long as their
      //  Urbit key revision number is 0, indicating that they have not yet
      //  been started.  To deposit a star this way, grant the CSR contract
      //  permission to transfer ownership of the star; the contract will
      //  transfer the star to itself.
      //
      uint16 prefix = ships.getPrefix(_star);
      if ( ships.isOwner(prefix, msg.sender) &&
           ships.isSpawnProxy(prefix, this) &&
           !ships.isActive(_star) )
      {
        //  first model: spawn _star to :this contract
        //
        Constitution(ships.owner()).spawn(_star, this);
      }
      else if ( ships.isOwner(_star, msg.sender) &&
                ships.isTransferProxy(_star, this) &&
                ships.isActive(_star) &&
                !ships.hasBeenBooted(_star) )
      {
        //  second model: transfer active, unused _star to :this contract
        //
        Constitution(ships.owner()).transferShip(_star, this, true);
      }
      else
      {
        //  star is not eligible for deposit
        //
        revert();
      }
      //  add _star to the participant's star balance
      //
      com.stars.push(_star);
    }

    //  withdrawForfeited(): withdraw one star from forfeiting _participant,
    //                       to :this contract owner's address _to
    //
    function withdrawForfeited(address _participant, address _to)
      external
      onlyOwner
    {
      Commitment storage com = commitments[_participant];

      //  withdraw is possible only if the participant has forfeited,
      //  the owner has not yet withdrawn all forfeited stars, and
      //  the participant still has stars left to withdraw
      //
      require( com.forfeit &&
               (com.forfeited > 0) );

      //  update contract state
      //
      com.forfeited = com.forfeited.sub(1);

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
    function withdrawOverdue(address _participant, address _to)
      external
      onlyOwner
    {
      //  this can only be done :escapeHatchTime after the first
      //  condition has been met
      //
      require( ( 0 != timestamps[0] ) &&
               ( block.timestamp > timestamps[0].add(escapeHatchTime) ) );

      //  update contract state
      //
      Commitment storage com = commitments[_participant];
      com.withdrawn = com.withdrawn.add(1);

      //  withdraw a star from the commitment (don't reset it because
      //  no one whom we don't trust has ever had control of it)
      //
      performWithdraw(com, _to, false);
    }

  //
  //  Functions for participants
  //

    //  approveCommitmentTransfer(): transfer the commitment to another address
    //
    function approveCommitmentTransfer(address _to)
      external
    {
      //  make sure the caller is a participant,
      //  and that the target isn't
      //
      require( 0 != commitments[msg.sender].total &&
               0 == commitments[_to].total );
      transfers[msg.sender] = _to;
    }

    //  transferCommitment(): make an approved transfer of _from's commitment
    //                        to the caller's address
    //
    function transferCommitment(address _from)
      external
    {
      //  make sure the :msg.sender is authorized to make this transfer
      //
      require(transfers[_from] == msg.sender);

      //  make sure the target isn't also a participant again,
      //  this could have changed since approveCommitmentTransfer
      //
      require(0 == commitments[msg.sender].total);

      //  copy the commitment to the :msg.sender and clear _from's
      //
      Commitment storage com = commitments[_from];
      commitments[msg.sender] = com;
      commitments[_from] = Commitment(new uint16[](0), 0, 0, 0,
                                      new uint16[](0), 0, false, 0);
      transfers[_from] = 0;
    }

    //  withdraw(): withdraw one star to the sender's address
    //
    function withdraw()
      external
    {
      withdraw(msg.sender);
    }

    //  withdraw(): withdraw one star from the sender's commitment to _to
    //
    function withdraw(address _to)
      public
    {
      Commitment storage com = commitments[msg.sender];

      //  to withdraw, the participant must have a star balance,
      //  be under their current withdrawal limit, and cannot
      //  withdraw forfeited stars
      //
      require( (com.stars.length > 0) &&
               (com.withdrawn < withdrawLimit(msg.sender)) &&
               (!com.forfeit || (com.stars.length > com.forfeited)) );

      //  update contract state
      //
      com.withdrawn = com.withdrawn.add(1);

      //  withdraw a star from the commitment
      //
      performWithdraw(com, _to, true);
    }

    //  forfeit(): forfeit all remaining stars from batch number _batch
    //             and all batches after it
    //
    function forfeit(uint8 _batch)
      external
    {
      Commitment storage com = commitments[msg.sender];

      //  the participant can forfeit if and only if the condition deadline
      //  is missed (has passed without confirmation), and has not
      //  previously forfeited
      //
      require( (deadlines[_batch] == timestamps[_batch]) &&
               !com.forfeit );

      //  forfeited: number of stars the participant will forfeit
      //
      uint16 forfeited = totalStars(com.batches, _batch);

      //  restrict :forfeited to the number of stars not withdrawn
      //
      if ( forfeited > com.total.sub(com.withdrawn) )
      {
        forfeited = com.total.sub(com.withdrawn);
      }

      //  update commitment metadata
      //
      com.forfeited = forfeited;
      com.forfeit = true;

      //  emit event
      //
      emit Forfeit(msg.sender, forfeited);
    }

  //
  //  Internal functions
  //

    //  performWithdraw(): withdraw a star from _commit to _to
    //
    function performWithdraw(Commitment storage _com, address _to, bool _reset)
      internal
    {
      //  star: star to forfeit (from end of array)
      //
      uint16 star = _com.stars[_com.stars.length.sub(1)];

      //  remove the star from the batch
      //
      _com.stars.length = _com.stars.length.sub(1);

      //  then transfer the star
      //
      Constitution(ships.owner()).transferShip(star, _to, _reset);
    }

  //
  //  Public operations and utilities
  //

    //  analyzeCondition(): analyze condition number _condition for completion;
    //                    set :timestamps[_condition] if either the condition's
    //                    deadline has passed, or its conditions have been met
    //
    function analyzeCondition(uint8 _condition)
      public
    {
      //  only analyze conditions that haven't been met yet
      //
      require(0 == timestamps[_condition]);


      //  if the deadline has passed, the condition is missed, and the
      //  deadline becomes the condition's timestamp.
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
      if ( //  if there is no condition, it is always met
           //
           (bytes32(0) == condition) ||
           //
           //  a real condition is met when it has achieved a majority vote
           //
           polls.documentHasAchievedMajority(condition) )
      {
        //  if the condition is met, set :timestamps[_condition] to the
        //  timestamp of the current eth block
        //
        timestamps[_condition] = block.timestamp;
        emit ConditionCompleted(_condition, block.timestamp);
      }
    }

    //  withdrawLimit(): return the number of stars _participant can withdraw
    //                   at the current block timestamp
    //
    function withdrawLimit(address _participant)
      public
      view
      returns (uint16 limit)
    {
      Commitment storage com = commitments[_participant];

      //  for each batch, calculate the current limit and add it to the total.
      //
      for (uint256 i = 0; i < timestamps.length; i++)
      {
        uint256 ts = timestamps[i];

        //  if a condition hasn't completed yet, there is nothing to add.
        //
        //    we don't break, because technically conditions can be met in
        //    any arbitrary order.
        //
        if ( ts == 0 )
        {
          continue;
        }

        //  a condition can't have been completed in the future
        //
        assert(ts <= block.timestamp);

        //  calculate the amount of stars available from this batch by
        //  multiplying the release rate (stars per :rateUnit) by the number
        //  of rateUnits that have passed since the condition completed
        //
        uint256 num = uint256(com.rate).mul(
                      block.timestamp.sub(ts) / com.rateUnit );

        //  bound the release rate by the batch amount
        //
        if ( num > com.batches[i] )
        {
          num = com.batches[i];
        }

        //  add it to the total limit
        //
        limit = limit.add(uint16(num));
      }

      //  limit can't be higher than the total amount of stars made available
      //
      assert(limit <= com.total);

      //  allow at least one star
      //
      if ( limit < 1 )
      {
        return 1;
      }
    }

    //  totalStars(): return the number of stars available after batch _from
    //                in the _batches array
    //
    function totalStars(uint16[] _batches, uint8 _from)
      public
      pure
      returns (uint16 total)
    {
      for (uint256 i = _from; i < _batches.length; i++)
      {
        total = total.add(_batches[i]);
      }
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

      //  return true if this contract holds as many stars as we'll ever
      //  be entitled to withdraw
      //
      return ( com.total.sub(com.withdrawn) == com.stars.length );
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
}
