// the urbit ship data store
// untested draft

pragma solidity 0.4.15;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Ships is Ownable
{

  event ChangedPilot(uint32 ship, address owner);
  event ChangedStatus(uint32 ship, State state, uint64 lock);
  event ChangedEscape(uint32 ship, uint32 escape);
  event ChangedParent(uint32 ship, uint16 parent);
  event ChangedKey(uint32 ship, bytes32 key);

  // operating state
  enum State
  {
    Latent, // belongs to parent
    Liquid, // ceded to contract
    Locked, // locked til birth (see Status.locked)
    Living  // fully active
  }

  // operating state + metadata
  struct Status
  {
    State state;
    uint64 locked; // locked until, only used for Locked state.
  }

  // all hard assets
  struct Hull
  {
    address pilot;
    Status status; // operating state
    bytes32 key; // public key, 0 if none
    uint256 revision; // key number
    uint16 parent;
    uint32 escape; // 65536 if no escape request active.
    mapping(address => bool) launchers;
  }

  // per ship: full ship state.
  mapping(uint32 => Hull) internal ships;
  // per owner: iterable list of owned ships.
  mapping(address => uint32[]) public pilots;
  // per owner: per ship: index in pilots array (for efficient deletion).
  //NOTE these describe the "nth array element", so they're at index n-1.
  mapping(address => mapping(uint32 => uint256)) private shipNumbers;

  function Ships()
  {
    //
  }

  // ++utl
  // utilities

  function getOriginalParent(uint32 _ship)
    constant
    public
    returns (uint16 parent)
  {
    if (_ship < 65536) { return uint16(_ship % 256); }
    return uint16(_ship % 65536);
  }

  // retrieve data from the Hull of the specified ship.
  // "Internal type [Hull] is not allowed for public state variables."
  function getShipData(uint32 _ship)
    constant
    public
    returns (address pilot,
             uint8 state,
             uint64 locked,
             bytes32 key,
             uint256 revision,
             uint16 parent,
             uint32 escape)
  {
    Hull storage ship = ships[_ship];
    return (ship.pilot,
            uint8(ship.status.state),
            ship.status.locked,
            ship.key,
            ship.revision,
            ship.parent,
            ship.escape);
  }

  function getOwnedShips()
    constant
    public
    returns (uint32[] ownedShips)
  {
    return pilots[msg.sender];
  }

  function hasPilot(uint32 _ship)
    constant
    public
    returns (bool result)
  {
    return !(isPilot(_ship, 0));
  }

  function isPilot(uint32 _ship, address _addr)
    constant
    public
    returns (bool result)
  {
    return (ships[_ship].pilot == _addr);
  }

  function setPilot(uint32 _ship, address _owner)
    onlyOwner
    public
  {
    address prev = ships[_ship].pilot;
    require(prev != _owner);
    if (prev != 0)
    {
      // retrieve current index
      uint256 i = shipNumbers[prev][_ship];
      assert(i > 0);
      i = i - 1;
      // copy last item to current index
      uint32[] storage pilot = pilots[prev];
      uint256 last = pilot.length - 1;
      pilot[i] = pilot[last];
      // delete last item
      delete(pilot[last]);
      pilot.length = last;
      shipNumbers[prev][_ship] = 0;
    }
    if (_owner != 0)
    {
      pilots[_owner].push(_ship);
      shipNumbers[_owner][_ship] = pilots[_owner].length;
    }
    ships[_ship].pilot = _owner;
    ChangedPilot(_ship, _owner);
  }

  function isState(uint32 _ship, State _state)
    constant
    public
    returns (bool equals)
  {
    return (ships[_ship].status.state == _state);
  }

  function setLiquid(uint32 _ship)
    onlyOwner
    public
  {
    ships[_ship].status.state = State.Liquid;
    ChangedStatus(_ship, State.Liquid, 0);
  }

  function getLocked(uint32 _ship)
    constant
    public
    returns (uint64 date)
  {
    return ships[_ship].status.locked;
  }

  function setLocked(uint32 _ship, uint64 _date)
    onlyOwner
    public
  {
    Status storage status = ships[_ship].status;
    status.locked = _date;
    status.state = State.Locked;
    ChangedStatus(_ship, State.Locked, _date);
  }

  function setLiving(uint32 _ship)
    onlyOwner
    public
  {
    ships[_ship].status.state = State.Living;
    ChangedStatus(_ship, State.Living, 0);
    ships[_ship].parent = getOriginalParent(_ship);
    ships[_ship].escape = 65536;
  }

  function getParent(uint32 _ship)
    constant
    public
    returns (uint16 parent)
  {
    return ships[_ship].parent;
  }

  function isEscape(uint32 _ship, uint16 _parent)
    constant
    public
    returns (bool equals)
  {
    return (ships[_ship].escape == _parent);
  }

  function setEscape(uint32 _ship, uint32 _parent)
    onlyOwner
    public
  {
    ships[_ship].escape = _parent;
    ChangedEscape(_ship, _parent);
  }

  function doEscape(uint32 _ship)
    onlyOwner
    public
  {
    Hull storage ship = ships[_ship];
    require(ship.escape < 65536);
    ship.parent = uint16(ship.escape);
    ChangedParent(_ship, uint16(ship.escape));
    ship.escape = 65536;
    ChangedEscape(_ship, 65536);
  }

  function getKey(uint32 _ship)
    constant
    public
    returns (bytes32 key, uint256 revision)
  {
    Hull storage ship = ships[_ship];
    return (ship.key, ship.revision);
  }

  function setKey(uint32 _ship, bytes32 _key)
    onlyOwner
    public
  {
    Hull storage ship = ships[_ship];
    ship.key = _key;
    ChangedKey(_ship, _key);
    ship.revision = ship.revision + 1;
  }

  function isLauncher(uint16 _star, address _launcher)
    constant
    public
    returns (bool result)
  {
    return ships[_star].launchers[_launcher];
  }

  function setLauncher(uint16 _star, address _launcher, bool _set)
    onlyOwner
    public
  {
    ships[_star].launchers[_launcher] = _set;
  }
}
