// simple agreement for future address space
// draft

pragma solidity 0.4.18;

import './Constitution.sol';

contract SAFAS is Ownable
{
  //TODO safemath

  event TrancheUnlocked(uint8 tranch, uint256 when);
  event Forfeit(address who, uint16 stars);

  Ships public ships;
  Votes public votes;

  uint256[3] public deadlines;  // deadlines per tranche.
  uint256[3] public timestamps; // unlock timestamps for tranches.

  // agreement details and balance.
  struct Investor
  {
    uint16[3] tranches; // release amounts.
    uint16 total;       // total stars to be released.
    uint16 rate;        // stars released per month.
    //
    uint16[] stars;     // remaining stars.
    uint16 withdrawn;   // total stars withdrawn.
    //
    bool forfeit;       // whether they have forfeited future stars.
    uint16 forfeited;   // amount of stars they have forfeited.
  }

  mapping(address => Investor) public investors; // registered agreements.

  function SAFAS(Ships _ships, uint256[3] _deadlines)
    public
  {
    // require deadlines to be sequential.
    require((_deadlines[0] < _deadlines[1])
            && (_deadlines[1] < _deadlines[2]));
    ships = _ships;
    votes = Constitution(ships.owner()).votes();
    deadlines = _deadlines;
    // the first tranche is unlocked right away.
    checkTranche(0);
  }

  // functions for the contract owner to call

  // register a new investor after they have signed the safas paper contract.
  // specify their address, the stars that unlock per tranche, and per month.
  function register(address _investor, uint16[3] _tranches, uint16 _rate)
    external
    onlyOwner
  {
    Investor storage inv = investors[_investor];
    inv.tranches = _tranches;
    inv.total = totalStars(_tranches, 0);
    inv.rate = _rate;
  }

  // deposit a star into this contract to eventually be made available for
  // withdrawal by the specified address.
  // make sure that either the star is latent and this contract is the
  // registered launcher for its parent galaxy, or that this contract is the
  // registered transferrer for the star itself.
  function deposit(address _investor, uint16 _star)
    external
    onlyOwner
  {
    Investor storage inv = investors[_investor];
    // ensure we can't deposit too many stars.
    require(inv.total > (inv.stars.length + inv.withdrawn));
    //NOTE the below logic has been copied from the pool contract.
    //TODO maybe we should make it available as a library?
    // there are two possible ways to deposit a star:
    // 1: for latent stars, grant the contract launch permission on a galaxy.
    //    the contract will launch the deposited star directly to itself.
    if (ships.isPilot(ships.getOriginalParent(_star), msg.sender)
        && ships.isLauncher(ships.getOriginalParent(_star), this))
    {
      // attempt to launch the star to us.
      Constitution(ships.owner()).launch(_star, this, 0);
    }
    // 2: for locked stars, grant the contract permission to transfer ownership
    //    of that star. the contract will transfer the deposited star to itself.
    else if (ships.isPilot(_star, msg.sender)
        && ships.isTransferrer(_star, this))
    {
      // only accept stars that aren't alive, that are reputationless, "clean".
      require(!ships.isState(_star, Ships.State.Living));
      // attempt to transfer the star to us.
      Constitution(ships.owner()).transferShip(_star, this, true);
    }
    // if neither of those are possible, error out.
    else
    {
      revert();
    }
    // finally, add the star to their balance.
    investors[_investor].stars.push(_star);
  }

  // withdraw a star from an investor who has forfeited (some of) their stars.
  function withdrawForfeited(address _investor, address _to)
    external
    onlyOwner
  {
    Investor storage inv = investors[_investor];
    // we can only do this if they have forfeited,
    // we haven't withdrawn everything they have forfeited,
    // and they still have stars left.
    require(inv.forfeit
            && inv.forfeited > 0
            && inv.stars.length > 0);
    uint16 star = inv.stars[inv.stars.length-1];
    // update contract state,
    inv.stars.length = inv.stars.length - 1;
    inv.forfeited = inv.forfeited - 1;
    // then transfer the star.
    Constitution(ships.owner()).transferShip(star, _to, false);
    // false because it saves gas (no reset operations) and since we're
    // transfering to ourselves we only need to trust ourselves about not having
    // put in weird permissions initially.
  }

  // functions for investors to call

  // withdraw to your own address.
  function withdraw()
    external
  {
    withdraw(msg.sender);
  }

  // withdraw one of your stars to the specified address.
  // can only withdraw when you still have stars left, are under your limit,
  // and haven't forfeited all of the remaining stars.
  function withdraw(address _to)
    public
  {
    Investor storage inv = investors[msg.sender];
    // to withdraw, we must have a balance left,
    // and be under our current limit,
    // and, if we forfeited, not withdraw stars we gave back.
    require(inv.stars.length > 0
            && inv.withdrawn < withdrawLimit(msg.sender)
            && (!inv.forfeit
                || (inv.stars.length > inv.forfeited)));
    uint16 star = inv.stars[inv.stars.length-1];
    // update contract state,
    inv.stars.length = inv.stars.length - 1;
    inv.withdrawn = inv.withdrawn + 1;
    // then transfer the star.
    Constitution(ships.owner()).transferShip(star, _to, true);
  }

  // when a tranche's deadline has been missed, you can choose to forfeit the
  // stars it and future tranches would've given you. doing this when you have
  // already withdrawn more than the amount of stars in the tranches before it,
  // all of your remaining stars are forfeited.
  function forfeit(uint8 _tranche)
    external
  {
    Investor storage inv = investors[msg.sender];
    // we can only forfeit if a tranche has hit its deadline,
    // and we haven't forfeited yet.
    require(deadlines[_tranche] == timestamps[_tranche]
            && !inv.forfeit);
    // calculate the amount of stars we're forfeiting.
    uint16 forfeited = totalStars(inv.tranches, _tranche);
    // this can never be higher than the amount of stars we still have left.
    if (forfeited > (inv.total - inv.withdrawn))
    {
      forfeited = (inv.total - inv.withdrawn);
    }
    inv.forfeited = forfeited;
    inv.forfeit = true;
    Forfeit(msg.sender, forfeited);
  }

  // utility

  // check whether the specified tranche has been unlocked.
  // a tranche is unlocked if either its deadline has passed or its conditions
  // are met.
  function checkTranche(uint8 _tranche)
    public
  {
    // only check for tranches that haven't been unlocked yet.
    require(timestamps[_tranche] == 0);
    // if the deadline has passed, that becomes the tranche's timestamp.
    if (block.timestamp > deadlines[_tranche])
    {
      timestamps[_tranche] = deadlines[_tranche];
      TrancheUnlocked(_tranche, deadlines[_tranche]);
      return;
    }
    // if the deadline hasn't passed, we check if conditions are met.
    bool conditionsMet = false;
    // first tranche unlocks when the constitution and related contracts go live
    if (_tranche == 0)
    {
      conditionsMet = true;
    }
    // second tranche unlocks when the senate indicates arvo is stable.
    else if (_tranche == 1)
    {
      conditionsMet = votes.abstractMajorityMap(
                        keccak256("arvo is stable"));
    }
    // third tranche unlocks when the senate indicates continuity is reached.
    else if (_tranche == 2)
    {
      conditionsMet = votes.abstractMajorityMap(
                        keccak256("continuity and security achieved"));
    }
    // if conditions have been met, we set the timestamp.
    if (conditionsMet)
    {
      timestamps[_tranche] = block.timestamp;
      TrancheUnlocked(_tranche, block.timestamp);
    }
  }

  // for a given investor, calculates their current withdrawal limit.
  // for each tranche that has been unlocked, we calculate the amount of months
  // since its unlocking and multiply that by the rate of stars per month.
  // every investor can always withdraw at least one star.
  function withdrawLimit(address _investor)
    public
    view
    returns (uint16 limit)
  {
    Investor storage inv = investors[_investor];
    // for every tranche, calculate the current limit and add it to the total.
    for (uint8 i = 0; i < 3; i++)
    {
      uint256 ts = timestamps[i];
      // if a tranche hasn't been unlocked yet, there is nothing to add.
      if (ts == 0) { continue; }
      assert(ts < block.timestamp);
      // calculate the amount of stars available from this tranche by
      // multiplying the unlock rate (stars per month) by the amount of months
      // that have passed since the tranche unlocked.
      uint256 num = (inv.rate * ((block.timestamp - ts) / 30 days));
      // the upper limit here is the amount of stars specified for this tranche.
      if (num > inv.tranches[i])
      {
        num = inv.tranches[i];
      }
      // add it to the total limit.
      limit = limit + uint16(num);
    }
    // limit can't be higher than the total amount of stars made available.
    assert(limit <= inv.total);
    // allow at least one star.
    if (limit < 1) { return 1; }
  }

  //TODO safemath
  // for a given set of tranches, counts the total amount of stars made
  // available from the specified tranch onward.
  function totalStars(uint16[3] _tranches, uint8 _from)
    public
    pure
    returns (uint16 total)
  {
    for (uint8 i = _from; i < 3; i++)
    {
      total = total + _tranches[i];
    }
  }

  // checks to see if the investor's balance contains sufficient stars.
  function verifyBalance(address _investor)
    external
    returns (bool correct)
  {
    Investor storage inv = investors[_investor];
    // remaining amount of stars + amount of stars we've withdrawn.
    return (inv.total == (inv.stars.length + inv.withdrawn));
  }
}
