// simple agreement for future address space
// draft

pragma solidity 0.4.18;

import './Constitution.sol';

//  TODO TODO: let participants transfer their right

//  SAFAS: this contract allows stars to be delivered to buyers who have
//         purchased future stars, conditionally on technical deadlines 
//         being hit.  If the deadlines are hit (as certified by a 
//         vote of the galaxies), stars are released to the buyers.
//         Once a deadline passes without a certifying vote, a buyer
//         may choose to back out of the transaction, forfeiting stars
//         to claim an offline refund.
//
contract SAFAS is Ownable
{
  //  TODO check if safemath is needed anywhere
  //
  //TODO safemath

  //  TrancheCompleted: :tranche has either been hit or missed
  //
  event TrancheCompleted(uint8 tranche, uint256 when);

  //  Forfeit: :who has chosen to forfeit :stars number of stars
  //
  event Forfeit(address who, uint16 stars);

  //  ships: public contract which stores ship state
  //  votes: public contract which registers votes
  //
  Ships public ships;
  Votes public votes;

  //  deadlines: deadlines after which, if missed, commitments can forfeit;
  //             if hit (as certified by a galaxy vote), commitments can
  //             withdraw their stars.
  //
  uint64[3] public deadlines;
 
  //  timestamps: timestamps when deadlines of the matching index were 
  //              hit; or 0 if not yet hit; or equal to the deadline if
  //              the deadline was missed.
  //
  uint64[3] public timestamps; // unlock timestamps for tranches.

  //  Commitment: structure that mirrors a signed paper contract
  //
  struct Commitment
  {
    //  tranches: number of stars to release in each tranche
    //
    uint16[3] tranches;

    //  total: tranches[0] + tranches[1] + tranches[2]
    //
    uint16 total;

    //  rate: number of stars released per month
    //
    uint16 rate;

    //  stars: specific stars assigned to this commitment, and not yet withdrawn
    //
    uint16[] stars;

    //  withdrawn: number of stars withdrawn by this commitment
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

  //  commitments: all registered purchase agreeements
  //
  mapping(address => Commitment) public commitments;

  //  SAFAS: configure SAFAS and reference ship and voting contracts
  //
  function SAFAS(Ships _ships, uint256[3] _deadlines)
    public
  {
    //  sanity check: deadlines must be sequential
    //
    require( (_deadlines[0] < _deadlines[1]) && 
             (_deadlines[1] < _deadlines[2]) );

    //  reference ship and voting contracts
    //
    ships = _ships;
    votes = Constitution(ships.owner()).votes();

    //  install deadlines
    //
    deadlines = _deadlines;

    //  the first tranche is defined to be unlocked when these contracts
    //  are posted to the blockchain
    //  
    analyzeTranche(0);
  }

  //
  //  Functions for the contract owner
  //
    //  register(): register a new SAFAS commitment 
    //
    function register(//  _participant: address of the paper contract signer
                      //  _tranches: number of stars unlocking per tranche
                      //  _rate: number of stars that unlock per 30 days
                      //
                      address _participant,
                      uint16[3] _tranches, 
                      uint16 _rate)
      external
      onlyOwner
    {
      Commitment storage com = commitments[_participant];

      com.tranches = _tranches;
      com.total = totalStars(_tranches, 0);
      com.rate = _rate;
    }

    //  deposit(): deposit a star into this contract for later withdrawal
    //
    function deposit(address _participant, uint16 _star)
      external
      onlyOwner
    {
      Commitment storage com = commitments[_participant];

      //  ensure we can't deposit more stars than the participant
      //  is entitled to 
      //
      //  TODO: safe math?
      //
      require(com.total > (com.stars.length + com.withdrawn));

      //  There are two ways to deposit a star.  One way is for a galaxy to
      //  grant the SAFAS contract permission to spawn its stars.  The SAFAS
      //  contract will spawn the star directly to itself.
      //
      //  The SAFAS contract can also accept existing stars, as long as their
      //  Urbit key revision number is 0, indicating that they have not yet 
      //  been started.  To deposit a star this way, grant the SAFAS contract 
      //  permission to transfer ownership of the star; the contract will 
      //  transfer the star to itself.
      //
      if ( ships.isOwner(ships.getPrefix(_star), msg.sender) &&
           ships.isSpawner(ships.getPrefix(_star), this) )
      {
        //  first model: spawn _star to :this contract
        //
        Constitution(ships.owner()).spawn(_star, this, 0);
      }
      else if ( ships.isOwner(_star, msg.sender) &&
                ships.isTransferrer(_star, this) )
      {
        //  second model: transfer active, unused _star to :this contract
        //
        require( ships.isActive(_star) &&
                 (0 == ships.getKeyRevisionNumber(_star)) );

        //  transfer the star to :this contract
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
               (com.forfeited > 0)
               (com.stars.length > 0) );

      //  star: star to forfeit (from end of array)
      //
      uint16 star = com.stars[com.stars.length-1];

      // update contract metadata
      //
      com.stars.length = com.stars.length - 1;
      com.forfeited = com.forfeited - 1;

      //  then transfer the star (don't reset it because no one whom we don't 
      //  trust has ever had control of it)
      //
      Constitution(ships.owner()).transferShip(star, _to, false);
    }

  //  
  //  Functions for participants
  //
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

      //  star: star being withdrawn
      //
      uint16 star = com.stars[com.stars.length - 1];

      //  update contract metadata
      //
      com.stars.length = com.stars.length - 1;
      com.withdrawn = com.withdrawn + 1;

      //  transfer :star
      //
      Constitution(ships.owner()).transferShip(star, _to, true);
    }

    //  forfeit(): forfeit all remaining stars from tranche number _tranche 
    //             and all tranches after it
    //
    function forfeit(uint8 _tranche)
      external
    {
      Commitment storage com = commitments[msg.sender];

      //  the participant can forfeit if and only if the tranche is missed
      //  (its deadline has passed without confirmation), and has not
      //  previously forfeited
      //
      require( (deadlines[_tranche] == timestamps[_tranche]) &&
               !com.forfeit );
      
      //  forfeited: number of stars the participant will forfeit
      //
      uint16 forfeited = totalStars(com.tranches, _tranche);

      //  restrict :forfeited to the number of stars not withdrawn
      //
      //    TODO safe math?
      //
      if ( (forfeited + com.withdrawn) > com.total )
      {
        forfeited = (com.total - com.withdrawn);
      }

      //  update commitment metadata
      //
      com.forfeited = forfeited;
      com.forfeit = true;

      //  propagate event
      //
      Forfeit(msg.sender, forfeited);
    }

  //
  //  Public operations and utilities
  //
    //  analyzeTranche(): analyze tranche number _tranche for completion;
    //                    set :timestamps[_tranche] if either the tranche's
    //                    deadline has passed, or its conditions have been met
    //
    function analyzeTranche(uint8 _tranche)
      public
    {
      //  only analyze tranches that haven't been unlocked yet
      //
      require(timestamps[_tranche] == 0);

      //  if the deadline has passed, the tranche is missed, and the
      //  deadline becomes the tranche's timestamp.
      //
      if (block.timestamp > deadlines[_tranche])
      {
        timestamps[_tranche] = deadlines[_tranche];
        TrancheCompleted(_tranche, deadlines[_tranche]);
        return;
      }

      //  conditionsMet: true if the tranche has met its success condition
      //
      bool conditionsMet = false;

      //  first tranche completes by default once this contract is live
      //
      if ( _tranche == 0 )
      {
        conditionsMet = true;
      }

      //  second tranche completes when the galaxies pass a stability resolution
      //
      else if ( _tranche == 1 )
      {
        conditionsMet = votes.abstractMajorityMap(
                          keccak256("arvo is stable"));
      }

      //  third tranche completes when the galaxies pass a 
      //  continuity/security resolution
      //
      else if ( _tranche == 2 )
      {
        conditionsMet = votes.abstractMajorityMap(
                          keccak256("continuity and security achieved"));
      }

      //  if the tranche is completed, set :timestamps[_tranche] to the
      //  timestamp of the current eth block
      //
      if ( conditionsMet )
      {
        timestamps[_tranche] = block.timestamp;
        TrancheCompleted(_tranche, block.timestamp);
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

      // for each tranche, calculate the current limit and add it to the total.
      //
      for (uint8 i = 0; i < 3; i++)
      {
        uint256 ts = timestamps[i];

        //  if a tranche hasn't completed yet, there is nothing to add.
        //
        if ( ts == 0 ) { 
          continue;
        }
        assert(ts <= block.timestamp);

        //  calculate the amount of stars available from this tranche by
        //  multiplying the release rate (stars per month) by the number
        //  of 30-day months that have passed since the tranche unlocked.
        //
        uint256 num = (com.rate * ((block.timestamp - ts) / 30 days));

        //  bound the release rate by the tranche count
        // 
        if ( num > com.tranches[i] ) 
        {
          num = com.tranches[i];
        }

        //  add it to the total limit.
        //
        limit = limit + uint16(num);
      }

      // limit can't be higher than the total amount of stars made available
      //
      assert(limit <= com.total);

      // allow at least one star
      //
      if ( limit < 1 ) 
        { return 1; }
    }

    //  totalStars(): return the number of stars available after tranche _from
    //                in the _tranches array
    //
    function totalStars(uint16[3] _tranches, uint8 _from)
      public
      pure
      returns (uint16 total)
    {
      //  TODO safemath
      //
      for (uint8 i = _from; i < 3; i++)
      {
        total = total + _tranches[i];
      }
    }

    //  verifyBalance: check the balance of _participant
    //
    function verifyBalance(address _participant)
      external
      returns (bool correct)
    {
      Commitment storage com = commitments[_participant];

      //  return count of remaining stars + stars we've withdrawn.
      //
      return (com.total == (com.stars.length + com.withdrawn));
    }
}
