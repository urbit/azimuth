// the urbit ethereum constitution
// untested draft

pragma solidity 0.4.15;

import './ConstitutionBase.sol';

contract Constitution is ConstitutionBase
{
  // a single spark is 1e18 units, because 18 decimal places need to be stored.
  uint256 constant public oneSpark = 1000000000000000000;

  // during contract construction, set the addresses of the (data) contracts we
  // rely on.
  // ownership of these contracts will need to be transfered to the constitution
  // after its contract address becomes known.
  function Constitution(Ships _ships, Votes _votes, Spark _USP)
  {
    ships = _ships;
    votes = _votes;
    USP = _USP;
  }

  // ++pub
  // public transactions which any ethereum address can sign.

  // spend a spark to claim a star.
  // the star claimed must be State.Liquid.
  //NOTE caller should first USP.approve(this, 1);
  function claimStar(uint16 _star)
    external
  {
    // only stars that have been liquified can be claimed, latent ones still
    // belong to their parent.
    require(ships.isState(_star, Ships.State.Liquid));
    ships.setPilot(_star, msg.sender);
    // "lock" the star, but make it available for booting immediately.
    //NOTE block.timestamp can possibly be in the future, but generally not by
    //     much. it is possible for a malicious miner to mess with the timestamp
    //     but there is no incentive for doing so here.
    ships.setLocked(_star, uint64(block.timestamp));
    // withdraw a single spark from the caller, then destroy it.
    USP.transferFrom(msg.sender, this, oneSpark);
    USP.burn(oneSpark);
  }

  // ++nav
  // transactions made by ship owners.

  // liquidate a star to receive a spark.
  // the star liquidated must be owned by the caller,
  // and be in Ships.State.Latent.
  function liquidateStar(uint16 _star)
    external
  {
    uint16 parent = ships.getOriginalParent(_star);
    // stars can only be liquidated by (the owner of) their direct parent.
    require(ships.isPilot(parent, msg.sender));
    // _star can't secretly be a galaxy, because it's its own parent, and can't
    // be two states at once.
    require(ships.isState(parent, Ships.State.Living));
    require(ships.isState(_star, Ships.State.Latent));
    // galaxy must be allowed to create more stars.
    require(canSpawn(parent));
    ships.setLiquid(_star);
    // galaxy has gained a child.
    ships.incrementChildren(parent);
    // create a single spark and give it to the sender.
    USP.mint(msg.sender, oneSpark);
  }

  // launch a star or planet, making a target address its owner.
  function launch(uint32 _ship, address _target)
    external
  {
    // only latent ships can be launched. liquid ones require a spark, locked
    // and living ones already have an owner.
    require(ships.isState(_ship, Ships.State.Latent));
    uint16 parent = ships.getOriginalParent(_ship);
    require(ships.isState(parent, Ships.State.Living));
    // galaxies need to adhere to star creation limitations.
    require(parent > 255 || canSpawn(parent));
    // the owner of a parent can always launch its children, other addresses
    // need explicit permission (the role of "launcher") to do so.
    require(ships.isPilot(parent, msg.sender)
            || ships.isLauncher(parent, msg.sender));
    ships.setPilot(_ship, _target);
    // "lock" the ship, but make it available for booting immediately.
    ships.setLocked(_ship, uint64(block.timestamp));
    // parent has gained a child.
    ships.incrementChildren(parent);
  }

  // allow the given address to launch children of the ship.
  function grantLaunchRights(uint16 _ship, address _launcher)
    external
    pilot(_ship)
    alive(_ship)
  {
    ships.setLauncher(_ship, _launcher, true);
  }

  // disallow the given address to launch children of the ship.
  function revokeLaunchRights(uint16 _ship, address _launcher)
    external
    pilot(_ship)
  {
    ships.setLauncher(_ship, _launcher, false);
  }

  // bring a locked ship to life and set its public key.
  function start(uint32 _ship, bytes32 _key)
    external
    pilot(_ship)
  {
    // locked ships can only be started after their locktime is over.
    require(ships.isState(_ship, Ships.State.Locked));
    require(ships.getLocked(_ship) <= block.timestamp);
    ships.setKey(_ship, _key);
    ships.setLiving(_ship);
    // if a galaxy becomes living, it gains the ability to vote. we keep track
    // of the amount of voters so we can calculate votes needed for majority.
    if (_ship < 256)
    {
      votes.incrementTotalVoters();
    }
  }

  // transfer a living ship to a different address.
  function transferShip(uint32 _ship, address _target, bool _resetKey)
    external
    pilot(_ship)
    alive(_ship)
  {
    // we may not always want to reset the ship's key, to allow for ownership
    // transfer without ship downtime. eg, when transfering to ourselves, away
    // from a compromised address.
    if (_resetKey)
    {
      ships.setKey(_ship, 0);
    }
    ships.setPilot(_ship, _target);
  }

  // set the public key for a ship.
  function rekey(uint32 _ship, bytes32 _key)
    external
    pilot(_ship)
    alive(_ship)
  {
    ships.setKey(_ship, _key);
  }

  // escape to a new parent.
  // takes effect when the new parent accepts the adoption.
  function escape(uint32 _ship, uint16 _parent)
    external
    pilot(_ship)
    alive(_parent)
  {
    ships.setEscape(_ship, _parent);
  }

  // accept an escaping ship.
  function adopt(uint16 _parent, uint32 _child)
    external
    pilot(_parent)
  {
    require(ships.isEscape(_child, _parent));
    // _child's parent becomes _parent, and its escape is reset to "no escape".
    ships.doEscape(_child);
  }

  // reject an escaping ship.
  function reject(uint16 _parent, uint32 _child)
    external
    pilot(_parent)
  {
    require(ships.isEscape(_child, _parent));
    // resets the child's escape to "no escape".
    ships.setEscape(_child, 65536);
  }

  // ++sen
  // transactions made by galaxy owners

  // vote on a new constitution contract
  function castVote(uint8 _galaxy, address _proposal, bool _vote)
    external
    pilot(_galaxy)
    alive(_galaxy)
  {
    // the votes contract returns true if a majority is achieved.
    bool majority = votes.castVote(_galaxy, _proposal, _vote);
    //NOTE the votes contract protects against this or an older contract being
    //     pushed as a "new" majority.
    if (majority)
    {
      // transfer ownership of the data and token contracts to the new
      // constitution, then self-destruct.
      upgrade(_proposal);
    }
  }

  // vote on a documented proposal's hash
  function castVote(uint8 _galaxy, bytes32 _proposal, bool _vote)
    external
    pilot(_galaxy)
    alive(_galaxy)
  {
    // majorities on abstract proposals get recorded within the votes contract
    // and have no impact on the constitution.
    votes.castVote(_galaxy, _proposal, _vote);
  }

  // ++urg
  // transactions made by the contract creator.

  // assign initial galaxy owner, birthdate and liquidity completion date.
  // can only be done once.
  function createGalaxy(uint8 _galaxy, address _target, uint64 _lockTime,
                        uint64 _completeTime)
    external
    onlyOwner
  {
    require(!ships.hasPilot(_galaxy));
    ships.setLocked(_galaxy, _lockTime);
    ships.setCompleted(_galaxy, _completeTime);
    ships.setPilot(_galaxy, _target);
  }

  // test if the galaxy can liquify/launch another star right now,
  // assuming it is living.
  function canSpawn(uint16 _parent)
    constant
    returns (bool can)
  {
    uint64 completed = ships.getCompleted(_parent);
    // after the completion date, they can launch everything.
    if (completed <= block.timestamp) { return true; }
    // if locktime is before completion time, they can't launch.
    uint64 locked = ships.getLocked(_parent);
    if (locked < completed) { return false; }
    uint256 curDiff = block.timestamp - locked; // living guarantees > 0.
    uint256 totDiff = completed - locked;
    // start out with 1 star, then grow over time.
    uint256 allowed = 1 + ((curDiff * 255) / totDiff);
    uint32 children = ships.getChildren(_parent);
    return (allowed > children);
  }

  // ++mod
  // function modifiers.

  // test if msg.sender is pilot of _ship.
  modifier pilot(uint32 _ship)
  {
    require(ships.isPilot(_ship, msg.sender));
    _;
  }

  // test if the _ship is live.
  modifier alive(uint32 _ship)
  {
    require(ships.isState(_ship, Ships.State.Living));
    _;
  }
}
