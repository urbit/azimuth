// the urbit ship data store
// 

pragma solidity 0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Ships is Ownable
{
  //  Transferred: :ship is now owned by :owner
  //
  event Transferred(uint32 ship, address owner);

  //  Activated: :ship is now activated
  //
  event Activated(uint32 ship);

  //  EscapeRequested: :ship has requested a new sponsor, :sponsor
  //
  event EscapeRequested(uint32 ship, uint32 sponsor);

  //  EscapeAccepted: :ship confirmed with a new sponsor, :sponsor
  //
  event EscapeAccepted(uint32 ship, uint32 sponsor);

  //  ChangedKey: :ship has a new Urbit public key, :crypt and :auth
  //
  event ChangedKey(uint32 ship, bytes32 crypt, bytes32 auth);

  //  Class: classes of ship registered on eth
  //
  enum Class 
  {
    Galaxy,
    Star,
    Planet
  }

  //  Hull: state of a ship
  //
  struct Hull
  {
    //  owner: eth address that owns this ship
    //
    address owner;

    //  active: whether ship can be run
    //    false: ship belongs to parent, cannot be booted
    //    true: ship has been, or can be, booted
    //
    bool active;

    //  spawnCount: for stars and galaxies, number of :active children
    //
    uint16 spawnCount;

    //  encryptionKey: Urbit curve25519 encryption key, or 0 for none
    //
    bytes32 encryptionKey;
   
    //  authenticationKey: Urbit ed25519 authentication key, or 0 for none
    //
    bytes32 authenticationKey;
   
    //  keyRevisionNumber: incremented every time we change the keys
    //
    uint32 keyRevisionNumber;

    //  sponsor: ship that supports this one on the network 
    //           (by default, the ship's half-width prefix)
    //
    uint32 sponsor;

    //  escapeRequested: true if the ship has requested to change sponsors
    //
    bool escapeRequested;

    //  escapeRequestedTo: if :escapeRequested is set, new sponsor requested
    //
    uint32 escapeRequestedTo;

    //  proxySpawn: 0, or another address with the right to spawn children
    //
    address proxySpawn;

    //  proxyTransfer: 0, or another address with the right to transfer owners
    //
    address proxyTransfer;
  }

  //  ships: all Urbit ship state
  //
  mapping(uint32 => Hull) internal ships;

  //  owners: per eth address, list of ships owned
  //
  mapping(address => uint32[]) public owners;

  //  shipOwnerIndexes: per owner per ship, (index + 1) in owners array
  //
  //    We delete owners by moving the last entry in the array to the
  //    newly emptied slot, which is (n - 1) where n is the value of
  //    shipOwnerIndexes[owner][ship].
  //
  mapping(address => mapping(uint32 => uint256)) public shipOwnerIndexes;

  //  operators: per owner, per address, has the right to transfer ownership
  //
  mapping(address => mapping(address => bool)) public operators;

  function Ships()
    public
  {
    //
  }

  //
  //  Utility functions
  //

  //  getPrefix: compute prefix parent of _ship
  //
  function getPrefix(uint32 _ship)
    pure
    public
    returns (uint16 parent)
  {
    if (_ship < 65536)
    {
      return uint16(_ship % 256);
    }
    return uint16(_ship % 65536);
  }

  //  getShipData: retrieve data from Hull
  //  XX: update for new Hull!!!
  //
  function getShipData(uint32 _ship)
    view
    public
    returns (address pilot,
             uint8 state,
             uint64 locked,
             uint64 completed,
             uint16 children,
             bytes32 key,
             uint256 revision,
             uint32 sponsor,
             uint32 escape,
             bool escaping,
             address transferrer)
  {
    Hull storage ship = ships[_ship];
    return (ship.pilot,
            uint8(ship.status.state),
            ship.status.locked,
            ship.status.completed,
            ship.children,
            ship.key,
            ship.revision,
            ship.sponsor,
            ship.escape,
            ship.escaping,
            ship.transferrer);
  }

  //  getOwnedShips(): return array of ships that :msg.sender owns
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getOwnedShips()
    view
    public
    returns (uint32[] ownedShips)
  {
    return owners[msg.sender];
  }

  //  getOwnedShips(): return array of ships that _whose owns
  //
  //    Note: only useful for clients, as Solidity does not currently
  //    support returning dynamic arrays.
  //
  function getOwnedShips(address _whose)
    view
    public
    returns (uint32[] ownedShips)
  {
    return owners[_whose];
  }

  //  getOwnedShipCount(): return length of array of ships that _whose owns
  // 
  function getOwnedShipCount(address _whose)
    view
    public
    returns (uint256 count)
  {
    return owners[_whose].length;
  }

  //  getOwnedShipAtIndex(): get ship at _index from array of ships that 
  //                         _whose owns
  //
  function getOwnedShipAtIndex(address _whose, uint256 _index)
    view
    public
    returns (uint32 ship)
  {
    uint32[] storage owned = owners[_whose];
    require(_index < owned.length);
    return owners[_whose][_index];
  }

  //  hasOwner(): true if _ship has a valid eth address as owner
  //
  function hasOwner(uint32 _ship)
    view
    public
    returns (bool result)
  {
    return !(isOwner(_ship, 0));
  }

  //  isOwner(): true if _ship is owned by _address
  //
  function isOwner(uint32 _ship, address _address)
    view
    public
    returns (bool result)
  {
    return (ships[_ship].pilot == _address);
  }

  //  getOwner(): return owner of _ship
  //
  function getOwner(uint32 _ship)
    view
    public
    returns (address pilot)
  {
    return ships[_ship].pilot;
  }

  //  setOwner(): set owner of _ship to _owner
  //
  //    Note: setOwner() only implements the minimal data storage
  //    logic for a transfer; use the constitution contract for a
  //    full transfer.
  //
  //    Note: _owner must not equal the present owner.
  //
  function setOwner(uint32 _ship, address _owner)
    onlyOwner
    public
  {
    //  prev: previous owner, if any
    //
    address prev = ships[_ship].pilot;

    //  don't use setOwner() to set to current owner
    //
    require(prev != _owner);

    //  if the ship used to have a different owner, do some gymnastics to
    //  keep the list of owned ships gapless.  delete this ship from the 
    //  list, then fill that gap with the list tail.
    //
    if (prev != 0)
    {
      //  i: current index in previous owner's list of owned ships
      //
      uint256 i = shipOwnerIndexes[prev][_ship];

      //  we store index + 1, because 0 is the eth default value
      //
      assert(i > 0);
      i--;

      //  copy the last item in the list into the now-unused slot
      //
      uint32[] storage pilot = owners[prev];
      uint256 last = pilot.length - 1;
      pilot[i] = pilot[last];

      //  delete the last item
      //
      delete(pilot[last]);
      pilot.length = last;
      shipOwnerIndexes[prev][_ship] = 0;
    }

    //  update the owner list and the owner's index list
    //
    if (_owner != 0)
    {
      owners[_owner].push(_ship);
      shipOwnerIndexes[_owner][_ship] = owners[_owner].length;
    }
    ships[_ship].pilot = _owner;
    ChangedOwner(_ship, _owner);
  }

  //  incrementChildren(): increment the number of children spawned by _ship
  //
  function incrementChildren(uint32 _ship)
    onlyOwner
    public
  {
    require(ships[_ship].children < 65535);
    ships[_ship].children++;
  }

  //  getSpawnCount(): return the number of children spawned by _ship
  //
  function getSpawnCount(uint32 _ship)
    view
    public
    returns (uint16 spawnCount)
  {
    return ships[_ship].spawnCount
  }

  //  isActive(): return true if ship is active
  //
  function isActive(uint32 _ship)
    view
    public
    returns (bool equals)
  {
    return (ships[_ship].active);
  }

  //  setActive(): activate ship
  //
  function setActive(uint32 _ship)
    onlyOwner
    public
  {
    //  XX
    //
    //  check that ship is inactive
    //  increment spawn count
  }

  function getSponsor(uint32 _ship)
    view
    public
    returns (uint32 sponsor)
  {
    return ships[_ship].sponsor;
  }

  function isEscaping(uint32 _ship)
    view
    public
    returns (bool escaping)
  {
    return ships[_ship].escaping;
  }

  function isEscape(uint32 _ship, uint32 _sponsor)
    view
    public
    returns (bool equals)
  {
    Hull storage ship = ships[_ship];
    return (ship.escaping && (ship.escape == _sponsor));
  }

  function setEscape(uint32 _ship, uint32 _sponsor)
    onlyOwner
    public
  {
    Hull storage ship = ships[_ship];
    ship.escape = _sponsor;
    ship.escaping = true;
    ChangedEscape(_ship, _sponsor);
  }

  function cancelEscape(uint32 _ship)
    onlyOwner
    public
  {
    ships[_ship].escaping = false;
  }

  function doEscape(uint32 _ship)
    onlyOwner
    public
  {
    Hull storage ship = ships[_ship];
    require(ship.escaping);
    ship.sponsor = ship.escape;
    ChangedSponsor(_ship, ship.escape);
    ship.escaping = false;
  }

  function getKey(uint32 _ship)
    view
    public
    returns (bytes32 key, uint256 revision)
  {
    Hull storage ship = ships[_ship];
    return (ship.key, ship.revision);
  }

  //  setKey: set Urbit public keys of _ship to _encryptionKey and
  //          _authenticationKey
  //
  function setKey(uint32 _ship, 
                  bytes32 _encryptionKey,
                  bytes32 _authenticationKey)
    onlyOwner
    public
  {
    Hull storage ship = ships[_ship];

    ship.encryptionKey = _encryptionKey;
    ship.authenticationKey = _authenticationKey;
    ship.keyRevisionNumber = ship.keyRevisionNumber + 1;

    ChangedKey(_ship, _encryptionKey, _authenticationKey);
  }

  function isSpawner(uint16 _star, address _spawner)
    view
    public
    returns (bool result)
  {
    return (ships[_star].spawner == _spawner);
  }

  function setSpawner(uint16 _star, address _spawner)
    onlyOwner
    public
  {
    ships[_star].spawner = _spawner;
  }

  function isTransferrer(uint32 _ship, address _transferrer)
    view
    public
    returns (bool result)
  {
    return (ships[_ship].transferrer == _transferrer);
  }

  function getTransferrer(uint32 _ship)
    view
    public
    returns (address transferrer)
  {
    return ships[_ship].transferrer;
  }

  function setTransferrer(uint32 _ship, address _transferrer)
    onlyOwner
    public
  {
    ships[_ship].transferrer = _transferrer;
  }

  function isOperator(address _owner, address _operator)
    view
    public
    returns (bool result)
  {
    return operators[_owner][_operator];
  }

  function setOperator(address _owner, address _operator, bool _approved)
    onlyOwner
    public
  {
    operators[_owner][_operator] = _approved;
  }

  //  getShipClass(): return the class of _ship
  //
  function getShipClass(uint32 _ship)
    public
    pure
    returns (uint8 _class)
  {
    if (_ship < 256) return 0;
    if (_ship < 65536) return 1;
    return 2;
  }
