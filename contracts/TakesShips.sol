//  contract that uses the Ships contract

pragma solidity 0.4.24;

import './ReadsShips.sol';
import './Constitution.sol';

contract TakesShips is ReadsShips
{
  constructor(Ships _ships)
    ReadsShips(_ships)
    public
  {
    //
  }

  //  takeShip(): transfer _ship to this contract. if _clean is true, require
  //              that the ship be unbooted.
  //              returns true if this succeeds, false otherwise.
  //
  function takeShip(uint32 _ship, bool _clean)
    internal
    returns (bool success)
  {
    //  There are two ways for a contract to get a ship.
    //  One way is for a parent ship to grant the contract permission to
    //  spawn its ships.
    //  The contract will spawn the ship directly to itself.
    //
    uint16 prefix = ships.getPrefix(_ship);
    if ( ships.isOwner(_ship, 0x0) &&
         ships.isOwner(prefix, msg.sender) &&
         ships.isSpawnProxy(prefix, this) )
         //NOTE  this might still fail because of spawn limit
    {
      //  first model: spawn _ship to :this contract
      //
      Constitution(ships.owner()).spawn(_ship, this);
      return true;
    }

    //  The second way is to accept existing ships, optionally requiring
    //  they be unbooted.
    //  To deposit a ship this way, the owner grants the contract
    //  permission to transfer ownership of the ship.
    //  The contract will transfer the ship to itself.
    //
    if ( (!_clean || !ships.hasBeenBooted(_ship)) &&
         ships.isOwner(_ship, msg.sender) &&
         ships.isTransferProxy(_ship, this) )
    {
      //  second model: transfer active, unused _ship to :this contract
      //
      Constitution(ships.owner()).transferShip(_ship, this, true);
      return true;
    }

    //  ship is not for us to take
    //
    return false;
  }

  //  giveShip(): transfer a _ship we own to _to, optionally resetting.
  //              returns true if this succeeds, false otherwise.
  //
  function giveShip(uint32 _ship, address _to, bool _reset)
    internal
    returns (bool success)
  {
    //  only give ships we've taken, ships we fully own
    //
    if (ships.isOwner(_ship, this))
    {
      Constitution(ships.owner()).transferShip(_ship, _to, _reset);
      return true;
    }

    //  ship is not for us to give
    //
    return false;
  }
}
