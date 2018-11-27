//  linear star release
//  https://azimuth.network

pragma solidity 0.4.24;

import './Ecliptic.sol';
import './TakesPoints.sol';

import './SafeMath16.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

//  LinearStarRelease: batch transfer over time
//
//    This contract allows its owner to transfer a batch of stars to a
//    recipient (also "participant") gradually, at a set rate of an
//    amount of stars per a period of time, after an optional waiting
//    period measured from the launch of this contract.
//
//    The owner of this contract can register batches and deposit stars
//    into them. Participants can withdraw stars as they get released
//    and transfer ownership of their batch to another address.
//    If, ten years after the contract launch, any stars remain, the
//    contract owner is able to withdraw them. This saves address space from
//    being lost forever in case of key loss by participants.
//
contract LinearStarRelease is Ownable, TakesPoints
{
  using SafeMath for uint256;
  using SafeMath16 for uint16;

  //  escapeHatchTime: amount of time after the time of contract launch, after
  //                   which the contract owner can withdraw arbitrary stars
  //
  uint256 constant escapeHatchTime = 10 * 365 days;

  //  start: global release start time
  //
  uint256 public start;

  //  Batch: stars that unlock for a participant
  //
  //    While the ordering of the struct members is semantically chaotic,
  //    they are ordered to tightly pack them into Ethereum's 32-byte storage
  //    slots, which reduces gas costs for some function calls.
  //    The comment ticks indicate assumed slot boundaries.
  //
  struct Batch
  {
    //  stars: specific stars assigned to this batch that have not yet
    //         been withdrawn
    //
    uint16[] stars;
  //
    //  windup: amount of time it takes for stars to start becoming
    //          available for withdrawal (start unlocking), after the
    //          release has started globally (:start)
    //
    uint256 windup;
  //
    //  rateUnit: amount of time it takes for the next :rate stars to be
    //            released/unlocked
    //
    uint256 rateUnit;
  //
    //  withdrawn: number of stars withdrawn from this batch
    //
    uint16 withdrawn;

    //  rate: number of stars released per :rateUnit
    //
    uint16 rate;

    //  amount: promised amount of stars
    //
    uint16 amount;

    //  approvedTransferTo: batch can be transferred to this address
    //
    address approvedTransferTo;
  }

  //  batches: per participant, the registered star release
  //
  mapping(address => Batch) public batches;

  //  constructor(): register azimuth contract
  //
  constructor(Azimuth _azimuth)
    TakesPoints(_azimuth)
    public
  {
    //
  }

  //
  //  Functions for the contract owner
  //

    //  register(): register a new star batch
    //
    function register( //  _participant: address of the participant
                       //  _windup: time until first release
                       //  _amount: the promised amount of stars
                       //  _rate: number of stars that unlock per _rateUnit
                       //  _rateUnit: amount of time it takes for the next
                       //             _rate stars to unlock
                       //
                       address _participant,
                       uint256 _windup,
                       uint16 _amount,
                       uint16 _rate,
                       uint256 _rateUnit )
      external
      onlyOwner
    {
      Batch storage batch = batches[_participant];

      //  make sure this participant doesn't already have a batch registered
      //
      require(0 == batch.amount);

      //  make sure batch details are sane
      //
      require( (_rate > 0) &&
               (_rateUnit > 0) &&
               (_amount > 0) );

      batch.windup = _windup;
      batch.amount = _amount;
      batch.rate = _rate;
      batch.rateUnit = _rateUnit;
    }

    //  deposit(): deposit a star into this contract for later withdrawal
    //
    function deposit(address _participant, uint16 _star)
      external
      onlyOwner
    {
      Batch storage batch = batches[_participant];

      //  ensure we can only deposit stars, and that we can't deposit
      //  more stars than necessary
      //
      require( (_star > 0xff) &&
               (batch.stars.length < batch.amount.sub(batch.withdrawn)) );

      //  have the contract take ownership of the star if possible,
      //  reverting if that fails.
      //
      require( takePoint(_star, true) );

      //  add _star to the participant's star balance
      //
      batch.stars.push(_star);
    }

    //  startReleasing(): start the process of releasing stars
    //
    function startReleasing()
      external
      onlyOwner
    {
      //  make sure we haven't started yet
      //
      require(0 == start);
      start = block.timestamp;
    }

    //  withdrawOverdue(): withdraw arbitrary star from the contract
    //
    //    this functions acts as an escape hatch in the case of key loss,
    //    to prevent blocks of address space from being lost permanently.
    //
    function withdrawOverdue(address _participant, address _to)
      external
      onlyOwner
    {
      //  this can only be done :escapeHatchTime after the release start
      //
      require( (0 < start) &&
               (block.timestamp > start.add(escapeHatchTime)) );

      //  withdraw a star from the batch
      //
      performWithdraw(batches[_participant], _to, false);
    }

  //
  //  Functions for participants
  //

    //  approveBatchTransfer(): transfer the batch to another address
    //
    function approveBatchTransfer(address _to)
      external
    {
      //  make sure the caller is a participant,
      //  and that the target isn't
      //
      require( 0 != batches[msg.sender].amount &&
               0 == batches[_to].amount );
      batches[msg.sender].approvedTransferTo = _to;
    }

    //  transferBatch(): make an approved transfer of _from's batch
    //                        to the caller's address
    //
    function transferBatch(address _from)
      external
    {
      //  make sure the :msg.sender is authorized to make this transfer
      //
      require(batches[_from].approvedTransferTo == msg.sender);

      //  make sure the target isn't also a participant
      //
      require(0 == batches[msg.sender].amount);

      //  copy the batch to the :msg.sender and clear _from's
      //
      Batch storage com = batches[_from];
      batches[msg.sender] = com;
      batches[_from] = Batch(new uint16[](0), 0, 0, 0, 0, 0, 0x0);
    }

    //  withdraw(): withdraw one star to the sender's address
    //
    function withdraw()
      external
    {
      withdraw(msg.sender);
    }

    //  withdraw(): withdraw one star from the sender's batch to _to
    //
    function withdraw(address _to)
      public
    {
      Batch storage batch = batches[msg.sender];

      //  to withdraw, the participant must have a star balance
      //  and be under their current withdrawal limit
      //
      require( (batch.stars.length > 0) &&
               (batch.withdrawn < withdrawLimit(msg.sender)) );

      //  withdraw a star from the batch
      //
      performWithdraw(batch, _to, true);
    }

  //
  //  Internal functions
  //

    //  performWithdraw(): withdraw a star from _batch to _to
    //
    function performWithdraw(Batch storage _batch, address _to, bool _reset)
      internal
    {
      //  star: star being withdrawn
      //
      uint16 star = _batch.stars[_batch.stars.length.sub(1)];

      //  remove the star from the batch
      //
      _batch.stars.length = _batch.stars.length.sub(1);
      _batch.withdrawn = _batch.withdrawn.add(1);

      //  transfer :star
      //
      require( givePoint(star, _to, _reset) );
    }

  //
  //  Public operations and utilities
  //

    //  withdrawLimit(): return the number of stars _participant can withdraw
    //                   at the current block timestamp
    //
    function withdrawLimit(address _participant)
      public
      view
      returns (uint16 limit)
    {
      //  if we haven't started releasing yet, limit is always zero
      //
      if (0 == start)
      {
        return 0;
      }

      uint256 allowed = 0;
      Batch storage batch = batches[_participant];

      //  only do real calculations if the windup time is over
      //
      if ( block.timestamp > start.add(batch.windup) )
      {
        //  calculate the amount of stars available from this batch by
        //  multiplying the release rate (stars per :rateUnit) by the number
        //  of :rateUnits that have passed since the windup period ended
        //
        allowed = uint256(batch.rate).mul(
                  ( block.timestamp.sub(start.add(batch.windup)) /
                    batch.rateUnit ) );
      }

      //  allow at least one star
      //
      if ( allowed < 1 )
      {
        return 1;
      }
      //
      //  don't allow more than the promised amount
      //
      else if (allowed > batch.amount)
      {
        return batch.amount;
      }
      return uint16(allowed);
    }

    //  verifyBalance: check the balance of _participant
    //
    //    Note: for use by clients, to verify the contract owner
    //    has deposited all the stars they're entitled to.
    //
    function verifyBalance(address _participant)
      external
      view
      returns (bool correct)
    {
      Batch storage batch = batches[_participant];

      //  return true if this contract holds as many stars as we'll ever
      //  be entitled to withdraw
      //
      return ( batch.amount.sub(batch.withdrawn) == batch.stars.length );
    }

    //  getRemainingStars(): get the stars deposited into the batch
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getRemainingStars(address _participant)
      external
      view
      returns (uint16[] stars)
    {
      return batches[_participant].stars;
    }
}
