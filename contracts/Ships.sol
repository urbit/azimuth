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

  //  ChangedKeys: :ship has new Urbit public keys, :crypt and :auth
  //
  event ChangedKeys(uint32 ship, bytes32 crypt, bytes32 auth);

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

    //  spawnProxy: 0, or another address with the right to spawn children
    //
    address spawnProxy;

    //  transferProxy: 0, or another address with the right to transfer owners
    //
    address transferProxy;
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
  //  Getters, setters and checks
  //

    //  getShipData: retrieve data from Hull
    //
    function getShipData(uint32 _ship)
      view
      public
      returns (address owner,
               bool active,
               uint16 spawnCount,
               bytes32 encryptionKey,
               bytes32 authenticationKey,
               uint256 keyRevisionNumber,
               uint32 sponsor,
               bool escapeRequested,
               uint32 escapeRequestedTo,
               address spawnProxy,
               address transferProxy)
    {
      Hull storage ship = ships[_ship];
      return (ship.owner,
              ship.active,
              ship.spawnCount,
              ship.encryptionKey,
              ship.authenticationKey,
              ship.keyRevisionNumber,
              ship.sponsor,
              ship.escapeRequested,
              ship.escapeRequestedTo,
              ship.spawnProxy,
              ship.transferProxy);
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

    //  isOwner(): true if _ship is owned by _address
    //
    function isOwner(uint32 _ship, address _address)
      view
      public
      returns (bool result)
    {
      return (ships[_ship].owner == _address);
    }

    //  getOwner(): return owner of _ship
    //
    function getOwner(uint32 _ship)
      view
      public
      returns (address owner)
    {
      return ships[_ship].owner;
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
      address prev = ships[_ship].owner;

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
        uint32[] storage owner = owners[prev];
        uint256 last = owner.length - 1;
        owner[i] = owner[last];

        //  delete the last item
        //
        delete(owner[last]);
        owner.length = last;
        shipOwnerIndexes[prev][_ship] = 0;
      }

      //  update the owner list and the owner's index list
      //
      if (_owner != 0)
      {
        owners[_owner].push(_ship);
        shipOwnerIndexes[_owner][_ship] = owners[_owner].length;
      }
      ships[_ship].owner = _owner;
      Transferred(_ship, _owner);
    }

    //  isActive(): return true if ship is active
    //
    function isActive(uint32 _ship)
      view
      public
      returns (bool equals)
    {
      return ships[_ship].active;
    }

    //  setActive(): activate ship
    //
    function setActive(uint32 _ship)
      onlyOwner
      public
    {
      //  make a ship active, increasing the spawn count of its prefix
      //
      Hull storage ship = ships[_ship];
      require(!ship.active);
      ship.active = true;
      if (_ship > 255)
      {
        ships[getPrefix(_ship)].spawnCount++;
      }
    }

    //  getSpawnCount(): return the number of children spawned by _ship
    //
    function getSpawnCount(uint32 _ship)
      view
      public
      returns (uint16 spawnCount)
    {
      return ships[_ship].spawnCount;
    }

    function getKeys(uint32 _ship)
      view
      public
      returns (bytes32 crypt, bytes32 auth)
    {
      Hull storage ship = ships[_ship];
      return (ship.encryptionKey,
              ship.authenticationKey);
    }

    function getKeyRevisionNumber(uint32 _ship)
      view
      public
      returns (uint32 revision)
    {
      return ships[_ship].keyRevisionNumber;
    }

    //  setKeys(): set Urbit public keys of _ship to _encryptionKey and
    //            _authenticationKey
    //
    function setKeys(uint32 _ship,
                     bytes32 _encryptionKey,
                     bytes32 _authenticationKey)
      onlyOwner
      public
    {
      Hull storage ship = ships[_ship];

      ship.encryptionKey = _encryptionKey;
      ship.authenticationKey = _authenticationKey;
      ship.keyRevisionNumber = ship.keyRevisionNumber + 1;

      ChangedKeys(_ship, _encryptionKey, _authenticationKey);
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
      return ships[_ship].escapeRequested;
    }

    function getEscape(uint32 _ship)
      view
      public
      returns (uint32 escape)
    {
      return ships[_ship].escapeRequestedTo;
    }

    function isEscape(uint32 _ship, uint32 _sponsor)
      view
      public
      returns (bool equals)
    {
      Hull storage ship = ships[_ship];
      return (ship.escapeRequested && (ship.escapeRequestedTo == _sponsor));
    }

    function setEscape(uint32 _ship, uint32 _sponsor)
      onlyOwner
      public
    {
      Hull storage ship = ships[_ship];
      ship.escapeRequestedTo = _sponsor;
      ship.escapeRequested = true;
      EscapeRequested(_ship, _sponsor);
    }

    function cancelEscape(uint32 _ship)
      onlyOwner
      public
    {
      ships[_ship].escapeRequested = false;
    }

    //  doEscape(): perform the requested escape
    //
    function doEscape(uint32 _ship)
      onlyOwner
      public
    {
      Hull storage ship = ships[_ship];
      require(ship.escapeRequested);
      ship.sponsor = ship.escapeRequestedTo;
      ship.escapeRequested = false;
      EscapeAccepted(_ship, ship.escapeRequestedTo);
    }

    function isSpawnProxy(uint32 _ship, address _spawner)
      view
      public
      returns (bool result)
    {
      return (ships[_ship].spawnProxy == _spawner);
    }

    function getSpawnProxy(uint32 _ship)
      view
      public
      returns (address spawnProxy)
    {
      return ships[_ship].spawnProxy;
    }

    function setSpawnProxy(uint32 _ship, address _spawner)
      onlyOwner
      public
    {
      ships[_ship].spawnProxy = _spawner;
    }

    function isTransferProxy(uint32 _ship, address _transferrer)
      view
      public
      returns (bool result)
    {
      return (ships[_ship].transferProxy == _transferrer);
    }

    function getTransferProxy(uint32 _ship)
      view
      public
      returns (address transferProxy)
    {
      return ships[_ship].transferProxy;
    }

    function setTransferProxy(uint32 _ship, address _transferrer)
      onlyOwner
      public
    {
      ships[_ship].transferProxy = _transferrer;
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

  //
  //  Utility functions
  //

    //  getPrefix(): compute prefix parent of _ship
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

    //  getShipClass(): return the class of _ship
    //
    function getShipClass(uint32 _ship)
      public
      pure
      returns (Class _class)
    {
      if (_ship < 256) return Class.Galaxy;
      if (_ship < 65536) return Class.Star;
      return Class.Planet;
    }
}
