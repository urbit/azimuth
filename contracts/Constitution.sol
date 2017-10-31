// the urbit ethereum constitution
// untested draft

pragma solidity 0.4.15;

import './ConstitutionBase.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract Constitution is ConstitutionBase
{
  using SafeMath for uint256;

  // during contract construction, set the addresses of the (data) contracts we
  // rely on.
  // ownership of these contracts will need to be transfered to the constitution
  // after its contract address becomes known.
  function Constitution(Ships _ships, Votes _votes)
  {
    ships = _ships;
    votes = _votes;
  }

  // ++nav
  // transactions made by ship owners.

  // launch a star or planet, making a target address its owner. the launched
  // ship becomes startable after the specified lock time.
  function launch(uint32 _ship, address _target, uint64 _lockTime)
    external
  {
    // only latent ships can be launched. locked and living ones already have an
    // owner.
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
    // lock the ship.
    ships.setLocked(_ship, _lockTime);
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
    alive(_ship)
  {
    ships.setLauncher(_ship, _launcher, false);
  }

  // allow the given address to transfer ownership of the ship.
  function allowTransferBy(uint32 _ship, address _transferrer)
    external
    pilot(_ship)
    unlocked(_ship)
  {
    ships.setTransferrer(_ship, _transferrer);
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

  // transfer an unlocked or living ship to a different address.
  function transferShip(uint32 _ship, address _target, bool _resetKey)
    external
    unlocked(_ship)
  {
    require(ships.isPilot(_ship, msg.sender)
            || ships.isTransferrer(_ship, msg.sender));
    // we may not always want to reset the ship's key, to allow for ownership
    // transfer without ship downtime. eg, when transfering to ourselves, away
    // from a compromised address.
    if (_resetKey)
    {
      ships.setKey(_ship, 0);
    }
    // we always reset the transferrer upon transfer, to ensure the new owner
    // doesn't have to worry about getting their ship transferred away.
    ships.setTransferrer(_ship, 0);
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
  function castConcreteVote(uint8 _galaxy, address _proposal, bool _vote)
    external
    pilot(_galaxy)
    alive(_galaxy)
  {
    // the votes contract returns true if a majority is achieved.
    bool majority = votes.castConcreteVote(_galaxy, _proposal, _vote);
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
  function castAbstractVote(uint8 _galaxy, bytes32 _proposal, bool _vote)
    external
    pilot(_galaxy)
    alive(_galaxy)
  {
    // majorities on abstract proposals get recorded within the votes contract
    // and have no impact on the constitution.
    votes.castAbstractVote(_galaxy, _proposal, _vote);
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

  // test if the galaxy can liquify/launch another star right now.
  function canSpawn(uint16 _parent)
    public
    constant
    returns (bool can)
  {
    if (!ships.isState(_parent, Ships.State.Living)) { return false; }
    uint64 completed = ships.getCompleted(_parent);
    // after the completion date, they can launch everything.
    if (completed <= block.timestamp) { return true; }
    // if unlocked after completion, only the above check remains important.
    uint64 locked = ships.getLocked(_parent);
    if (completed <= locked) { return false; }
    uint256 curDiff = block.timestamp.sub(locked); // living guarantees > 0.
    uint256 totDiff = uint256(completed).sub(locked);
    // start out with 1 star, then grow over time.
    uint256 allowed = curDiff.mul(254).div(totDiff).add(1);
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

  // test if the _ship is either locked and past its locktime, or live.
  modifier unlocked(uint32 _ship)
  {
    require(ships.isState(_ship, Ships.State.Living)
            || (ships.isState(_ship, Ships.State.Locked)
                && ships.getLocked(_ship) < block.timestamp));
    _;
  }
}
