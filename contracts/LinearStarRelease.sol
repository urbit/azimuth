//  linear star release

pragma solidity 0.4.21;

import './Constitution.sol';

//  LinearStarRelease: batch transfer over time
//
//    This contract allows its owner to transfer a batch of stars to a
//    recipient (also "participant") gradually, at a set rate of an
//    amount of stars per a period of time, after an optional waiting
//    period measured from the launch of this contract.
//
//    The owner of the contract can register batches and deposit stars
//    into them. Participants can withdraw stars as they get released
//    and transfer ownership of their batch to another address.
//
contract LinearStarRelease is Ownable
{
  //  ships: public contract which stores ship state
  //
  Ships public ships;

  //  start: time of contract launch
  //
  uint256 public start;

  //  Batch: stars that unlock for a participant
  //
  struct Batch
  {
    //  windup: amount of time it takes for stars to stars becoming
    //          available for withdrawal
    //
    uint256 windup;

    //  rate: number of stars released per :rateUnit
    //
    uint16 rate;

    //  rateUnit: amount of time it takes for the next :rate stars to be
    //            released
    //
    uint256 rateUnit;

    //  amount: promised amount of stars
    //
    uint16 amount;

    //  stars: specific stars assigned to this batch that have not yet
    //         been withdrawn
    //
    uint16[] stars;

    //  withdrawn: number of stars withdrawn by this batch
    //
    uint16 withdrawn;
  }

  //  batches: per participant, the registered star release
  //
  mapping(address => Batch) public batches;

  //  transfers: approved batch transfers
  //
  mapping(address => address) public transfers;

  //  LinearStarRelease: configure ships contract and set starting date
  //
  function LinearStarRelease(Ships _ships)
    public
  {
    ships = _ships;
    start = block.timestamp;
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
      //  make sure a sane rate is submitted
      //
      require(_rate > 0);

      Batch storage batch = batches[_participant];
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

      //  ensure we can't deposit more stars than the participant
      //  is entitled to
      //
      require( batch.stars.length < (batch.amount - batch.withdrawn) );

      //  There are two ways to deposit a star.  One way is for a galaxy to
      //  grant the LSR contract permission to spawn its stars.  The LSR
      //  contract will spawn the star directly to itself.
      //
      //  The LSR contract can also accept existing stars, as long as their
      //  Urbit key revision number is 0, indicating that they have not yet
      //  been started.  To deposit a star this way, grant the LSR contract
      //  permission to transfer ownership of the star; the contract will
      //  transfer the star to itself.
      //
      if ( ships.isOwner(ships.getPrefix(_star), msg.sender) &&
           ships.isSpawnProxy(ships.getPrefix(_star), this) &&
           !ships.isActive(_star) )
      {
        //  first model: spawn _star to :this contract
        //
        Constitution(ships.owner()).spawn(_star, this);
      }
      else if ( ships.isOwner(_star, msg.sender) &&
                ships.isTransferProxy(_star, this) &&
                ships.isActive(_star) &&
                (0 == ships.getKeyRevisionNumber(_star)) )
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
      batch.stars.push(_star);
    }

  //
  //  Functions for participants
  //

    //  approveBatchTransfer(): transfer the batch to another address
    //
    function approveBatchTransfer(address _to)
      external
    {
      //  make sure the target isn't also a participant
      //
      require(0 == batches[_to].amount);
      transfers[msg.sender] = _to;
    }

    //  transferBatch(): make an approved transfer of _from's batch
    //                        to the caller's address
    //
    function transferBatch(address _from)
      external
    {
      //  make sure the :msg.sender is authorized to make this transfer
      //
      require(transfers[_from] == msg.sender);

      //  make sure the target isn't also a participant
      //
      require(0 == batches[msg.sender].amount);

      //  copy the batch to the :msg.sender and clear _from's
      //
      Batch storage com = batches[_from];
      batches[msg.sender] = com;
      batches[_from] = Batch(0, 0, 0, 0, new uint16[](0), 0);
      transfers[_from] = 0;
    }

    //  withdraw(): withdraw one star to the sender's address
    //
    //TODO  overloading seems bugged for functions without arguments.
    /* function withdraw()
      external
    {
      withdraw(msg.sender);
    } */

    //  withdraw(): withdraw one star from the sender's batch to _to
    //
    function withdraw(address _to)
      public
    {
      Batch storage com = batches[msg.sender];

      //  to withdraw, the participant must have a star balance,
      //  be under their current withdrawal limit, and cannot
      //  withdraw forfeited stars
      //
      require( (com.stars.length > 0) &&
               (com.withdrawn < withdrawLimit(msg.sender)) );

      //  star: star being withdrawn
      //
      uint16 star = com.stars[com.stars.length - 1];

      //  update contract state
      //
      com.stars.length = com.stars.length - 1;
      com.withdrawn = com.withdrawn + 1;

      //  transfer :star
      //
      Constitution(ships.owner()).transferShip(star, _to, true);
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
      uint256 allowed = 0;
      Batch storage batch = batches[_participant];

      //  only do real calculations if the windup time is over
      //
      if ( block.timestamp > (start + batch.windup) )
      {
        //  calculate the amount of stars available from this batch by
        //  multiplying the release rate (stars per :rateUnit) by the number
        //  of rateUnits that have passed since the windup period ended
        //
        allowed = batch.rate *
                  ( (block.timestamp - (start + batch.windup)) /
                    batch.rateUnit );
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
    function verifyBalance(address _participant)
      external
      view
      returns (bool correct)
    {
      Batch storage batch = batches[_participant];

      //  return true if this contract holds as many stars as we'll ever
      //  be entitled to withdraw
      //
      return ( (batch.amount - batch.withdrawn) == batch.stars.length );
    }

    //  getRemainingStars(): get the stars deposited into the batch
    //
    function getRemainingStars(address _participant)
      external
      view
      returns (uint16[] stars)
    {
      return batches[_participant].stars;
    }
}
