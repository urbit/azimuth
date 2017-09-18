// the urbit ethereum constitution
// untested draft

pragma solidity 0.4.15;

import './ConstitutionBase.sol';
import './Spark.sol';

contract Constitution is ConstitutionBase
{
  function Constitution(Ships _ships, Votes _votes)
  {
    ships = _ships;
    votes = _votes;
    USP = new Spark();
  }

  function mintSpark(address _target)
    private
  {
    USP.mint(_target, 1);
  }

  // ++pub
  // public transactions which any ethereum address can sign.

  // spend a spark to claim a star.
  // the star claimed must be State.Liquid.
  //NOTE caller should first USP.approve(this, 1);
  function claimStar(uint16 _star)
    external
  {
    require(ships.isState(_star, Ships.State.Liquid));
    ships.setPilot(_star, msg.sender);
    //NOTE block.timestamp can possibly be in the future, but generally not by
    //     much. it is possible for a malicious miner to mess with the timestamp
    //     but there is no incentive for doing so here.
    ships.setLocked(_star, uint64(block.timestamp));
    //TODO or *actually* burn the token?
    USP.transferFrom(msg.sender, 0, 1);
  }

  // ++nav
  // transactions made by ship owners.

  // liquidate a star to receive a spark.
  // the ship liquidated must be owned by the caller,
  // and be in Ships.State.Latent.
  //TODO batch operation?
  function liquidateStar(uint16 _star)
    external
    parent(_star)
  {
    require(ships.isState(_star, Ships.State.Latent));
    ships.setLiquid(_star);
    mintSpark(msg.sender);
  }

  // launch a star or planet, making a target address its owner.
  function launch(uint32 _ship, address _target)
    external
  {
    require(ships.isState(_ship, Ships.State.Latent));
    uint16 parent = ships.getOriginalParent(_ship);
    require(parent == _ship || ships.isState(parent, Ships.State.Living));
    require(ships.isPilot(parent, msg.sender)
            || ships.isLauncher(parent, msg.sender));
    ships.setPilot(_ship, _target);
    ships.setLocked(_ship, uint64(block.timestamp));
  }

  // allow the given address to launch planets belonging to the star.
  function grantLaunchRights(uint16 _star, address _launcher)
    external
    pilot(_star)
  {
    require(ships.isState(_star, Ships.State.Living));
    ships.setLauncher(_star, _launcher, true);
  }

  // disallow the given address to launch planets belonging to the star.
  function revokeLaunchRights(uint16 _star, address _launcher)
    external
    pilot(_star)
  {
    ships.setLauncher(_star, _launcher, false);
  }

  // bring a locked ship to life and set its public key.
  function start(uint32 _ship, bytes32 _key)
    external
    pilot(_ship)
  {
    require(ships.isState(_ship, Ships.State.Locked));
    require(ships.getLocked(_ship) <= block.timestamp);
    ships.setKey(_ship, _key);
    ships.setLiving(_ship);
    if (_ship < 256)
    {
      votes.incrementTotalVoters();
    }
  }

  // transfer a living ship to a different address.
  function transferShip(uint32 _ship, address _target)
    external
    pilot(_ship)
  {
    ships.setKey(_ship, 0);
    ships.setPilot(_ship, _target);
  }

  // set the public key for a ship.
  function rekey(uint32 _ship, bytes32 _key)
    external
    pilot(_ship)
  {
    ships.setKey(_ship, _key);
  }

  // escape to a new parent.
  // takes effect when the new parent accepts the adoption.
  function escape(uint32 _ship, uint16 _parent)
    external
    pilot(_ship)
  {
    ships.setEscape(_ship, _parent);
  }

  // accept an escaping ship.
  function adopt(uint16 _parent, uint32 _child)
    external
    pilot(_parent)
  {
    require(ships.isEscape(_child, _parent));
    ships.doEscape(_child);
  }

  // reject an escaping ship.
  function reject(uint16 _parent, uint32 _child)
    external
    pilot(_parent)
  {
    require(ships.isEscape(_child, _parent));
    ships.setEscape(_child, 65536);
  }

  // ++sen
  // transactions made by galaxy owners

  function castVote(uint8 _galaxy, address _proposal, bool _vote)
    external
    pilot(_galaxy)
    alive(_galaxy)
  {
    bool majority = votes.castVote(_galaxy, _proposal, _vote);
    //NOTE the votes contract protects against this or an older contract being
    //     pushed as a "new" majority.
    if (majority)
    {
      upgrade(_proposal);
    }
  }

  function castVote(uint8 _galaxy, bytes32 _proposal, bool _vote)
    external
    pilot(_galaxy)
    alive(_galaxy)
  {
    votes.castVote(_galaxy, _proposal, _vote);
  }

  // ++urg
  // transactions made by the contract creator.

  // assign initial galaxy owner and birthdate. can only be done once.
  function createGalaxy(uint8 _galaxy, address _target, uint64 _date)
    external
    onlyOwner
  {
    require(!ships.hasPilot(_galaxy));
    ships.setLocked(_galaxy, _date);
    ships.setPilot(_galaxy, _target);
  }

  // ++mod
  // function modifiers.

  // test if msg.sender is pilot of _ship.
  modifier pilot(uint32 _ship)
  {
    require(ships.isPilot(_ship, msg.sender));
    _;
  }

  // test if msg.sender is pilot of _ship's original parent.
  modifier parent(uint32 _ship)
  {
    require(ships.isPilot(ships.getOriginalParent(_ship), msg.sender));
    _;
  }

  // test if the _ship is live.
  modifier alive(uint32 _ship)
  {
    require(ships.isState(_ship, Ships.State.Living));
    _;
  }
}
