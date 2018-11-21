//  the azimuth ship data store

pragma solidity 0.4.24;

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

//  Ships: ship state data contract
//
//    This contract is used for storing all data related to Azimuth addresses
//    and their ownership. Consider this contract the Azimuth ledger.
//
//    It also contains permissions data, which ties in to ERC721
//    functionality. Operators of an address are allowed to transfer
//    ownership of all ships owned by their associated address
//    (ERC721's approveAll()). A transfer proxy is allowed to transfer
//    ownership of a single ship (ERC721's approve()).
//    Separate from ERC721 are managers, assigned per ship. They are
//    allowed to perform "low-impact" operations on the owner's ships,
//    like configuring public keys and making escape requests.
//
//    Since data stores are difficult to upgrade, this contract contains
//    as little actual business logic as possible. Instead, the data stored
//    herein can only be modified by this contract's owner, which can be
//    changed and is thus upgradable/replacable.
//
//    Initially, this contract will be owned by the Constitution contract.
//
contract Ships is Ownable
{
  //  OwnerChanged: :ship is now owned by :owner
  //
  event OwnerChanged(uint32 indexed ship, address indexed owner);

  //  Activated: :ship is now activate
  //
  event Activated(uint32 indexed ship);

  //  Spawned: :parent has spawned :child.
  //
  event Spawned(uint32 indexed parent, uint32 child);

  //  EscapeRequested: :ship has requested a new sponsor, :sponsor
  //
  event EscapeRequested(uint32 indexed ship, uint32 indexed sponsor);

  //  EscapeCanceled: :ship's :sponsor request was canceled or rejected
  //
  event EscapeCanceled(uint32 indexed ship, uint32 indexed sponsor);

  //  EscapeAccepted: :ship confirmed with a new sponsor, :sponsor
  //
  event EscapeAccepted(uint32 indexed ship, uint32 indexed sponsor);

  //  LostSponsor: :ship's sponsor is now refusing it service
  //
  event LostSponsor(uint32 indexed ship, uint32 indexed sponsor);

  //  ChangedKeys: :ship has new network public keys, :crypt and :auth
  //
  event ChangedKeys( uint32 indexed ship,
                     bytes32 encryptionKey,
                     bytes32 authenticationKey,
                     uint32 cryptoSuiteVersion,
                     uint32 keyRevisionNumber );

  //  BrokeContinuity: :ship has a new continuity number, :number.
  //
  event BrokeContinuity(uint32 indexed ship, uint32 number);

  //  ChangedSpawnProxy: :ship has a new spawn proxy
  //
  event ChangedSpawnProxy(uint32 indexed ship, address indexed spawnProxy);

  //  ChangedTransferProxy: :ship has a new transfer proxy
  //
  event ChangedTransferProxy( uint32 indexed ship,
                              address indexed transferProxy );

  //  ChangedManagementProxy: :manager can now manage :ship
  //
  event ChangedManagementProxy(uint32 indexed ship, address indexed manager);

  //  ChangedVotingProxy: :voter can now vote using :ship
  //
  event ChangedVotingProxy(uint32 indexed ship, address indexed voter);

  //  ChangedDns: dnsDomains has been updated
  //
  event ChangedDns(string primary, string secondary, string tertiary);

  //  Class: classes of ship registered on-chain
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
    //  active: whether ship can be run
    //
    //    false: ship belongs to parent, cannot be booted
    //    true: ship has been, or can be, booted
    //
    bool active;

    //  encryptionKey: curve25519 encryption key, or 0 for none
    //
    bytes32 encryptionKey;

    //  authenticationKey: ed25519 authentication key, or 0 for none
    //
    bytes32 authenticationKey;

    //  cryptoSuiteVersion: version of the crypto suite used for the pubkeys
    //
    uint32 cryptoSuiteVersion;

    //  keyRevisionNumber: incremented every time we change the public keys
    //
    uint32 keyRevisionNumber;

    //  continuityNumber: incremented to indicate network-side state loss
    //
    uint32 continuityNumber;

    //  spawned: for stars and galaxies, all :active children
    //
    uint32[] spawned;

    //  sponsor: ship that supports this one on the network, or,
    //           if :hasSponsor is false, the last ship that supported it.
    //           (by default, the ship's half-width prefix)
    //
    uint32 sponsor;

    //  hasSponsor: true if the sponsor still supports the ship
    //
    bool hasSponsor;

    //  escapeRequested: true if the ship has requested to change sponsors
    //
    bool escapeRequested;

    //  escapeRequestedTo: if :escapeRequested is set, new sponsor requested
    //
    uint32 escapeRequestedTo;
  }

  struct Deed
  {
    //  owner: address that owns this ship
    //
    address owner;

    //  managementProxy: 0, or another address with the right to perform
    //                   low-impact, managerial tasks
    //
    address managementProxy;

    //  votingProxy: 0, or another address with the right to vote as this ship
    //
    address votingProxy;

    //  spawnProxy: 0, or another address with the right to spawn children
    //
    address spawnProxy;

    //  transferProxy: 0, or another address with the right to transfer owners
    //
    address transferProxy;
  }

  //  ships: per ship, general network-relevant ship state
  //
  mapping(uint32 => Hull) public ships;

  //  rights: per ship, on-chain ownership and permissions
  //
  mapping(uint32 => Deed) public rights;

  //  shipsOwnedBy: per address, list of ships owned
  //
  mapping(address => uint32[]) public shipsOwnedBy;

  //  shipOwnerIndexes: per owner per ship, (index + 1) in shipsOwnedBy array
  //
  //    We delete owners by moving the last entry in the array to the
  //    newly emptied slot, which is (n - 1) where n is the value of
  //    shipOwnerIndexes[owner][ship].
  //
  mapping(address => mapping(uint32 => uint256)) public shipOwnerIndexes;

  //  operators: per owner, per address, has the right to transfer ownership
  //             of all the owner's ships (ERC721)
  //
  mapping(address => mapping(address => bool)) public operators;

  //  managerFor: per address, the ships they are managing
  //
  mapping(address => uint32[]) public managerFor;

  //  managerForIndexes: per address, per ship, (index + 1) in
  //                      the managerFor array
  //
  mapping(address => mapping(uint32 => uint256)) public managerForIndexes;

  //  votingFor: per address, the ships they can vote with
  //
  mapping(address => uint32[]) public votingFor;

  //  votingForIndexes: per address, per ship, (index + 1) in
  //                    the votingFor array
  //
  mapping(address => mapping(uint32 => uint256)) public votingForIndexes;

  //  transferringFor: per address, the ships they are transfer proxy for
  //
  mapping(address => uint32[]) public transferringFor;

  //  transferringForIndexes: per address, per ship, (index + 1) in
  //                          the transferringFor array
  //
  mapping(address => mapping(uint32 => uint256)) public transferringForIndexes;

  //  spawningFor: per address, the ships they are spawn proxy for
  //
  mapping(address => uint32[]) public spawningFor;

  //  spawningForIndexes: per address, per ship, (index + 1) in
  //                      the spawningFor array
  //
  mapping(address => mapping(uint32 => uint256)) public spawningForIndexes;

  //  sponsoring: per ship, the ships they are sponsoring
  //
  mapping(uint32 => uint32[]) public sponsoring;

  //  sponsoringIndexes: per ship, per ship, (index + 1) in
  //                     the sponsoring array
  //
  mapping(uint32 => mapping(uint32 => uint256)) public sponsoringIndexes;

  //  escapeRequests: per ship, the ships they have open escape requests from
  //
  mapping(uint32 => uint32[]) public escapeRequests;

  //  escapeRequestsIndexes: per ship, per ship, (index + 1) in
  //                         the escapeRequests array
  //
  mapping(uint32 => mapping(uint32 => uint256)) public escapeRequestsIndexes;

  //  dnsDomains: base domains for contacting galaxies
  //
  //    dnsDomains[0] is primary, the others are used as fallbacks
  //
  string[3] public dnsDomains;

  //  constructor(): configure default dns domains
  //
  constructor()
    public
  {
    setDnsDomains("example.com", "example.com", "example.com");
  }

  //
  //  Getters, setters and checks
  //

    //  setDnsDomains(): set the base domains used for contacting galaxies
    //
    //    Note: since a string is really just a byte[], and Solidity can't
    //    work with two-dimensional arrays yet, we pass in the three
    //    domains as individual strings.
    //
    function setDnsDomains(string _primary, string _secondary, string _tertiary)
      onlyOwner
      public
    {
      dnsDomains[0] = _primary;
      dnsDomains[1] = _secondary;
      dnsDomains[2] = _tertiary;
      emit ChangedDns(_primary, _secondary, _tertiary);
    }

    //  getOwnedShips(): return array of ships that :msg.sender owns
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getOwnedShips()
      view
      external
      returns (uint32[] ownedShips)
    {
      return shipsOwnedBy[msg.sender];
    }

    //  getOwnedShipsByAddress(): return array of ships that _whose owns
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getOwnedShipsByAddress(address _whose)
      view
      external
      returns (uint32[] ownedShips)
    {
      return shipsOwnedBy[_whose];
    }

    //  getOwnedShipCount(): return length of array of ships that _whose owns
    //
    function getOwnedShipCount(address _whose)
      view
      external
      returns (uint256 count)
    {
      return shipsOwnedBy[_whose].length;
    }

    //  getOwnedShipAtIndex(): get ship at _index from array of ships that
    //                         _whose owns
    //
    function getOwnedShipAtIndex(address _whose, uint256 _index)
      view
      external
      returns (uint32 ship)
    {
      uint32[] storage owned = shipsOwnedBy[_whose];
      require(_index < owned.length);
      return owned[_index];
    }

    //  isOwner(): true if _ship is owned by _address
    //
    function isOwner(uint32 _ship, address _address)
      view
      external
      returns (bool result)
    {
      return (rights[_ship].owner == _address);
    }

    //  getOwner(): return owner of _ship
    //
    function getOwner(uint32 _ship)
      view
      external
      returns (address owner)
    {
      return rights[_ship].owner;
    }

    //  setOwner(): set owner of _ship to _owner
    //
    //    Note: setOwner() only implements the minimal data storage
    //    logic for a transfer; use the constitution contract for a
    //    full transfer.
    //
    //    Note: _owner must not be the zero address.
    //
    function setOwner(uint32 _ship, address _owner)
      onlyOwner
      external
    {
      //  prevent burning of ships by making zero the owner
      //
      require(0x0 != _owner);

      //  prev: previous owner, if any
      //
      address prev = rights[_ship].owner;

      if (prev == _owner)
      {
        return;
      }

      //  if the ship used to have a different owner, do some gymnastics to
      //  keep the list of owned ships gapless.  delete this ship from the
      //  list, then fill that gap with the list tail.
      //
      if (0x0 != prev)
      {
        //  i: current index in previous owner's list of owned ships
        //
        uint256 i = shipOwnerIndexes[prev][_ship];

        //  we store index + 1, because 0 is the solidity default value
        //
        assert(i > 0);
        i--;

        //  copy the last item in the list into the now-unused slot,
        //  making sure to update its :shipOwnerIndexes reference
        //
        uint32[] storage owner = shipsOwnedBy[prev];
        uint256 last = owner.length - 1;
        uint32 moved = owner[last];
        owner[i] = moved;
        shipOwnerIndexes[prev][moved] = i + 1;

        //  delete the last item
        //
        delete(owner[last]);
        owner.length = last;
        shipOwnerIndexes[prev][_ship] = 0;
      }

      //  update the owner list and the owner's index list
      //
      rights[_ship].owner = _owner;
      shipsOwnedBy[_owner].push(_ship);
      shipOwnerIndexes[_owner][_ship] = shipsOwnedBy[_owner].length;
      emit OwnerChanged(_ship, _owner);
    }

    function isManagementProxy(uint32 _ship, address _manager)
      view
      external
      returns (bool result)
    {
      return (rights[_ship].managementProxy == _manager);
    }

    function getManagementProxy(uint32 _ship)
      view
      external
      returns (address manager)
    {
      return rights[_ship].managementProxy;
    }

    //  canManage(): true if _who is the owner of _ship,
    //               or the manager of _ship's owner
    //
    function canManage(uint32 _ship, address _who)
      view
      external
      returns (bool result)
    {
      Deed storage deed = rights[_ship];
      return ( (_who == deed.owner) ||
               (_who == deed.managementProxy) );
    }

    function setManagementProxy(uint32 _ship, address _manager)
      onlyOwner
      external
    {
      Deed storage deed = rights[_ship];
      address prev = deed.managementProxy;
      if (prev == _manager)
      {
        return;
      }

      //  if the ship used to have a different manager, do some gymnastics
      //  to keep the reverse lookup gapless.  delete the ship from the
      //  old manager's list, then fill that gap with the list tail.
      //
      if (0x0 != prev)
      {
        //  i: current index in previous manager's list of managed ships
        //
        uint256 i = managerForIndexes[prev][_ship];

        //  we store index + 1, because 0 is the solidity default value
        //
        assert(i > 0);
        i--;

        //  copy the last item in the list into the now-unused slot,
        //  making sure to update its :managerForIndexes reference
        //
        uint32[] storage prevMfor = managerFor[prev];
        uint256 last = prevMfor.length - 1;
        uint32 moved = prevMfor[last];
        prevMfor[i] = moved;
        managerForIndexes[prev][moved] = i + 1;

        //  delete the last item
        //
        delete(prevMfor[last]);
        prevMfor.length = last;
        managerForIndexes[prev][_ship] = 0;
      }

      if (0x0 != _manager)
      {
        uint32[] storage mfor = managerFor[_manager];
        mfor.push(_ship);
        managerForIndexes[_manager][_ship] = mfor.length;
      }

      deed.managementProxy = _manager;
      emit ChangedManagementProxy(_ship, _manager);
    }

    function getManagerForCount(address _manager)
      view
      external
      returns (uint256 count)
    {
      return managerFor[_manager].length;
    }

    //  getManagerFor(): get the owners _manager is a manager for
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getManagerFor(address _manager)
      view
      external
      returns (uint32[] mfor)
    {
      return managerFor[_manager];
    }

    function isVotingProxy(uint32 _ship, address _voter)
      view
      external
      returns (bool result)
    {
      return (rights[_ship].votingProxy == _voter);
    }

    function getVotingProxy(uint32 _ship)
      view
      external
      returns (address voter)
    {
      return rights[_ship].votingProxy;
    }

    //  canVoteAs(): true if _who is the owner of _ship,
    //               or the voting proxy of _ship's owner
    //
    function canVoteAs(uint32 _ship, address _who)
      view
      external
      returns (bool result)
    {
      Deed storage deed = rights[_ship];
      return ( (_who == deed.owner) ||
               (_who == deed.votingProxy) );
    }

    function setVotingProxy(uint32 _ship, address _voter)
      onlyOwner
      external
    {
      Deed storage deed = rights[_ship];
      address prev = deed.votingProxy;
      if (prev == _voter)
      {
        return;
      }

      //  if the ship used to have a different voter, do some gymnastics
      //  to keep the reverse lookup gapless.  delete the ship from the
      //  old voter's list, then fill that gap with the list tail.
      //
      if (0x0 != prev)
      {
        //  i: current index in previous voter's list of ships it was
        //     voting for
        //
        uint256 i = votingForIndexes[prev][_ship];

        //  we store index + 1, because 0 is the solidity default value
        //
        assert(i > 0);
        i--;

        //  copy the last item in the list into the now-unused slot,
        //  making sure to update its :votingForIndexes reference
        //
        uint32[] storage prevVfor = votingFor[prev];
        uint256 last = prevVfor.length - 1;
        uint32 moved = prevVfor[last];
        prevVfor[i] = moved;
        votingForIndexes[prev][moved] = i + 1;

        //  delete the last item
        //
        delete(prevVfor[last]);
        prevVfor.length = last;
        votingForIndexes[prev][_ship] = 0;
      }

      if (0x0 != _voter)
      {
        uint32[] storage vfor = votingFor[_voter];
        vfor.push(_ship);
        votingForIndexes[_voter][_ship] = vfor.length;
      }

      deed.votingProxy = _voter;
      emit ChangedVotingProxy(_ship, _voter);
    }

    function getVotingForCount(address _voter)
      view
      external
      returns (uint256 count)
    {
      return votingFor[_voter].length;
    }

    //  getVotingFor(): get the owners _voter is a voter for
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getVotingFor(address _voter)
      view
      external
      returns (uint32[] vfor)
    {
      return votingFor[_voter];
    }

    //  isActive(): return true if ship is active
    //
    function isActive(uint32 _ship)
      view
      external
      returns (bool equals)
    {
      return ships[_ship].active;
    }

    //  activateShip(): activate a ship, register it as spawned by its parent
    //
    function activateShip(uint32 _ship)
      onlyOwner
      external
    {
      //  make a ship active, setting its sponsor to its prefix
      //
      Hull storage ship = ships[_ship];
      require(!ship.active);
      ship.active = true;
      registerSponsor(_ship, true, getPrefix(_ship));
      emit Activated(_ship);
    }

    //  registerSpawn(): add a ship to its parent's list of spawned ships
    //
    function registerSpawned(uint32 _ship)
      onlyOwner
      external
    {
      //  if a ship is its own prefix (a galaxy) then don't register it
      //
      uint32 prefix = getPrefix(_ship);
      if (prefix == _ship)
      {
        return;
      }

      //  register a new spawned ship for the prefix
      //
      ships[prefix].spawned.push(_ship);
      emit Spawned(prefix, _ship);
    }

    function getKeys(uint32 _ship)
      view
      external
      returns (bytes32 crypt, bytes32 auth, uint32 suite, uint32 revision)
    {
      Hull storage ship = ships[_ship];
      return (ship.encryptionKey,
              ship.authenticationKey,
              ship.cryptoSuiteVersion,
              ship.keyRevisionNumber);
    }

    function getKeyRevisionNumber(uint32 _ship)
      view
      external
      returns (uint32 revision)
    {
      return ships[_ship].keyRevisionNumber;
    }

    //  hasBeenBooted(): returns true if the ship has ever been assigned keys
    //
    function hasBeenBooted(uint32 _ship)
      view
      external
      returns (bool result)
    {
      return ( ships[_ship].keyRevisionNumber > 0 );
    }

    //  isLive(): returns true if _ship currently has keys properly configured
    //
    function isLive(uint32 _ship)
      view
      external
      returns (bool result)
    {
      Hull storage ship = ships[_ship];
      return ( ship.encryptionKey != 0 &&
               ship.authenticationKey != 0 &&
               ship.cryptoSuiteVersion != 0 );
    }

    //  setKeys(): set network public keys of _ship to _encryptionKey and
    //            _authenticationKey
    //
    function setKeys(uint32 _ship,
                     bytes32 _encryptionKey,
                     bytes32 _authenticationKey,
                     uint32 _cryptoSuiteVersion)
      onlyOwner
      external
    {
      Hull storage ship = ships[_ship];
      if ( ship.encryptionKey == _encryptionKey &&
           ship.authenticationKey == _authenticationKey &&
           ship.cryptoSuiteVersion == _cryptoSuiteVersion )
      {
        return;
      }

      ship.encryptionKey = _encryptionKey;
      ship.authenticationKey = _authenticationKey;
      ship.cryptoSuiteVersion = _cryptoSuiteVersion;
      ship.keyRevisionNumber++;

      emit ChangedKeys(_ship,
                       _encryptionKey,
                       _authenticationKey,
                       _cryptoSuiteVersion,
                       ship.keyRevisionNumber);
    }

    function getContinuityNumber(uint32 _ship)
      view
      external
      returns (uint32 continuityNumber)
    {
      return ships[_ship].continuityNumber;
    }

    function incrementContinuityNumber(uint32 _ship)
      onlyOwner
      external
    {
      Hull storage ship = ships[_ship];
      ship.continuityNumber++;
      emit BrokeContinuity(_ship, ship.continuityNumber);
    }

    //  getSpawnCount(): return the number of children spawned by _ship
    //
    function getSpawnCount(uint32 _ship)
      view
      external
      returns (uint32 spawnCount)
    {
      uint256 len = ships[_ship].spawned.length;
      assert(len < 2**32);
      return uint32(len);
    }

    //  getSpawned(): return array ships spawned under _ship
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getSpawned(uint32 _ship)
      view
      external
      returns (uint32[] spawned)
    {
      return ships[_ship].spawned;
    }

    function getSponsor(uint32 _ship)
      view
      external
      returns (uint32 sponsor)
    {
      return ships[_ship].sponsor;
    }

    function hasSponsor(uint32 _ship)
      view
      external
      returns (bool has)
    {
      return ships[_ship].hasSponsor;
    }

    function isSponsor(uint32 _ship, uint32 _sponsor)
      view
      external
      returns (bool result)
    {
      Hull storage ship = ships[_ship];
      return ( ship.hasSponsor &&
               (ship.sponsor == _sponsor) );
    }

    function loseSponsor(uint32 _ship)
      onlyOwner
      external
    {
      Hull storage ship = ships[_ship];
      if (!ship.hasSponsor)
      {
        return;
      }
      registerSponsor(_ship, false, ship.sponsor);
      emit LostSponsor(_ship, ship.sponsor);
    }

    function isEscaping(uint32 _ship)
      view
      external
      returns (bool escaping)
    {
      return ships[_ship].escapeRequested;
    }

    function getEscapeRequest(uint32 _ship)
      view
      external
      returns (uint32 escape)
    {
      return ships[_ship].escapeRequestedTo;
    }

    function isRequestingEscapeTo(uint32 _ship, uint32 _sponsor)
      view
      public
      returns (bool equals)
    {
      Hull storage ship = ships[_ship];
      return (ship.escapeRequested && (ship.escapeRequestedTo == _sponsor));
    }

    function setEscapeRequest(uint32 _ship, uint32 _sponsor)
      onlyOwner
      external
    {
      if (isRequestingEscapeTo(_ship, _sponsor))
      {
        return;
      }
      registerEscapeRequest(_ship, true, _sponsor);
      emit EscapeRequested(_ship, _sponsor);
    }

    function cancelEscape(uint32 _ship)
      onlyOwner
      external
    {
      Hull storage ship = ships[_ship];
      if (!ship.escapeRequested)
      {
        return;
      }
      uint32 request = ship.escapeRequestedTo;
      registerEscapeRequest(_ship, false, 0);
      emit EscapeCanceled(_ship, request);
    }

    //  doEscape(): perform the requested escape
    //
    function doEscape(uint32 _ship)
      onlyOwner
      external
    {
      Hull storage ship = ships[_ship];
      require(ship.escapeRequested);
      registerSponsor(_ship, true, ship.escapeRequestedTo);
      registerEscapeRequest(_ship, false, 0);
      emit EscapeAccepted(_ship, ship.sponsor);
    }

    function getSponsoringCount(uint32 _sponsor)
      view
      external
      returns (uint256 count)
    {
      return sponsoring[_sponsor].length;
    }

    //  getSponsoring(): get the ships _sponsor is a sponsor for
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getSponsoring(uint32 _sponsor)
      view
      external
      returns (uint32[] sponsees)
    {
      return sponsoring[_sponsor];
    }

    function getEscapeRequestsCount(uint32 _sponsor)
      view
      external
      returns (uint256 count)
    {
      return escapeRequests[_sponsor].length;
    }

    //  getEscapeRequests(): get the ships _sponsor has received escape
    //                       requests from
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getEscapeRequests(uint32 _sponsor)
      view
      external
      returns (uint32[] requests)
    {
      return escapeRequests[_sponsor];
    }

    function isSpawnProxy(uint32 _ship, address _spawner)
      view
      external
      returns (bool result)
    {
      return (rights[_ship].spawnProxy == _spawner);
    }

    function getSpawnProxy(uint32 _ship)
      view
      external
      returns (address spawnProxy)
    {
      return rights[_ship].spawnProxy;
    }

    function setSpawnProxy(uint32 _ship, address _spawner)
      onlyOwner
      external
    {
      Deed storage deed = rights[_ship];
      address prev = deed.spawnProxy;
      if (prev == _spawner)
      {
        return;
      }

      //  if the ship used to have a different spawn proxy, do some
      //  gymnastics to keep the reverse lookup gapless.  delete the ship
      //  from the old proxy's list, then fill that gap with the list tail.
      //
      if (0x0 != prev)
      {
        //  i: current index in previous proxy's list of spawning ships
        //
        uint256 i = spawningForIndexes[prev][_ship];

        //  we store index + 1, because 0 is the solidity default value
        //
        assert(i > 0);
        i--;

        //  copy the last item in the list into the now-unused slot,
        //  making sure to update its :spawningForIndexes reference
        //
        uint32[] storage prevSfor = spawningFor[prev];
        uint256 last = prevSfor.length - 1;
        uint32 moved = prevSfor[last];
        prevSfor[i] = moved;
        spawningForIndexes[prev][moved] = i + 1;

        //  delete the last item
        //
        delete(prevSfor[last]);
        prevSfor.length = last;
        spawningForIndexes[prev][_ship] = 0;
      }

      if (0x0 != _spawner)
      {
        uint32[] storage sfor = spawningFor[_spawner];
        sfor.push(_ship);
        spawningForIndexes[_spawner][_ship] = sfor.length;
      }

      deed.spawnProxy = _spawner;
      emit ChangedSpawnProxy(_ship, _spawner);
    }

    function getSpawningForCount(address _proxy)
      view
      external
      returns (uint256 count)
    {
      return spawningFor[_proxy].length;
    }

    //  getSpawningFor(): get the ships _proxy is a spawn proxy for
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getSpawningFor(address _proxy)
      view
      external
      returns (uint32[] sfor)
    {
      return spawningFor[_proxy];
    }

    function isTransferProxy(uint32 _ship, address _transferrer)
      view
      external
      returns (bool result)
    {
      return (rights[_ship].transferProxy == _transferrer);
    }

    function getTransferProxy(uint32 _ship)
      view
      external
      returns (address transferProxy)
    {
      return rights[_ship].transferProxy;
    }

    //  setTransferProxy(): configure _transferrer as transfer proxy for _ship
    //
    function setTransferProxy(uint32 _ship, address _transferrer)
      onlyOwner
      external
    {
      Deed storage deed = rights[_ship];
      address prev = deed.transferProxy;
      if (prev == _transferrer)
      {
        return;
      }

      //  if the ship used to have a different transfer proxy, do some
      //  gymnastics to keep the reverse lookup gapless.  delete the ship
      //  from the old proxy's list, then fill that gap with the list tail.
      //
      if (0x0 != prev)
      {
        //  i: current index in previous proxy's list of transferable ships
        //
        uint256 i = transferringForIndexes[prev][_ship];

        //  we store index + 1, because 0 is the solidity default value
        //
        assert(i > 0);
        i--;

        //  copy the last item in the list into the now-unused slot,
        //  making sure to update its :transferringForIndexes reference
        //
        uint32[] storage prevTfor = transferringFor[prev];
        uint256 last = prevTfor.length - 1;
        uint32 moved = prevTfor[last];
        prevTfor[i] = moved;
        transferringForIndexes[prev][moved] = i + 1;

        //  delete the last item
        //
        delete(prevTfor[last]);
        prevTfor.length = last;
        transferringForIndexes[prev][_ship] = 0;
      }

      if (0x0 != _transferrer)
      {
        uint32[] storage tfor = transferringFor[_transferrer];
        tfor.push(_ship);
        transferringForIndexes[_transferrer][_ship] = tfor.length;
      }

      deed.transferProxy = _transferrer;
      emit ChangedTransferProxy(_ship, _transferrer);
    }

    function getTransferringForCount(address _proxy)
      view
      external
      returns (uint256 count)
    {
      return transferringFor[_proxy].length;
    }

    //  getTransferringFor(): get the ships _proxy is a transfer proxy for
    //
    //    Note: only useful for clients, as Solidity does not currently
    //    support returning dynamic arrays.
    //
    function getTransferringFor(address _proxy)
      view
      external
      returns (uint32[] tfor)
    {
      return transferringFor[_proxy];
    }

    function isOperator(address _owner, address _operator)
      view
      external
      returns (bool result)
    {
      return operators[_owner][_operator];
    }

    //  setOperator(): dis/allow _operator to transfer ownership of all ships
    //                 owned by _owner
    //
    //    operators are part of the ERC721 standard
    //
    function setOperator(address _owner, address _operator, bool _approved)
      onlyOwner
      external
    {
      operators[_owner][_operator] = _approved;
    }

  //
  //  Utility functions
  //

    //  registerSponsor(): set the sponsorship state of _ship and update the
    //                reverse lookup for sponsors
    //
    function registerSponsor(uint32 _ship, bool _hasSponsor, uint32 _sponsor)
      internal
    {
      Hull storage ship = ships[_ship];
      bool had = ship.hasSponsor;
      uint32 prev = ship.sponsor;
      if ( (!had && !_hasSponsor) ||
           (had && _hasSponsor && prev == _sponsor) )
      {
        return;
      }

      //  if the ship used to have a different sponsor, do some gymnastics
      //  to keep the reverse lookup gapless.  delete the ship from the old
      //  sponsor's list, then fill that gap with the list tail.
      //
      if (had)
      {
        //  i: current index in previous sponsor's list of sponsored ships
        //
        uint256 i = sponsoringIndexes[prev][_ship];

        //  we store index + 1, because 0 is the solidity default value
        //
        assert(i > 0);
        i--;

        //  copy the last item in the list into the now-unused slot,
        //  making sure to update its :sponsoringIndexes reference
        //
        uint32[] storage prevSponsoring = sponsoring[prev];
        uint256 last = prevSponsoring.length - 1;
        uint32 moved = prevSponsoring[last];
        prevSponsoring[i] = moved;
        sponsoringIndexes[prev][moved] = i + 1;

        //  delete the last item
        //
        delete(prevSponsoring[last]);
        prevSponsoring.length = last;
        sponsoringIndexes[prev][_ship] = 0;
      }

      if (_hasSponsor)
      {
        uint32[] storage newSponsoring = sponsoring[_sponsor];
        newSponsoring.push(_ship);
        sponsoringIndexes[_sponsor][_ship] = newSponsoring.length;
      }

      ship.sponsor = _sponsor;
      ship.hasSponsor = _hasSponsor;
    }

    //  registerEscapeRequest(): set the escape state of _ship and update the
    //                           reverse lookup for sponsors
    //
    function registerEscapeRequest( uint32 _ship,
                                    bool _isEscaping, uint32 _sponsor )
      internal
    {
      Hull storage ship = ships[_ship];
      bool was = ship.escapeRequested;
      uint32 prev = ship.escapeRequestedTo;
      if ( (!was && !_isEscaping) ||
           (was && _isEscaping && prev == _sponsor) )
      {
        return;
      }

      //  if the ship used to have a different request, do some gymnastics
      //  to keep the reverse lookup gapless.  delete the ship from the old
      //  sponsor's list, then fill that gap with the list tail.
      //
      if (was)
      {
        //  i: current index in previous sponsor's list of sponsored ships
        //
        uint256 i = escapeRequestsIndexes[prev][_ship];

        //  we store index + 1, because 0 is the solidity default value
        //
        assert(i > 0);
        i--;

        //  copy the last item in the list into the now-unused slot,
        //  making sure to update its :escapeRequestsIndexes reference
        //
        uint32[] storage prevRequests = escapeRequests[prev];
        uint256 last = prevRequests.length - 1;
        uint32 moved = prevRequests[last];
        prevRequests[i] = moved;
        escapeRequestsIndexes[prev][moved] = i + 1;

        //  delete the last item
        //
        delete(prevRequests[last]);
        prevRequests.length = last;
        escapeRequestsIndexes[prev][_ship] = 0;
      }

      if (_isEscaping)
      {
        uint32[] storage newRequests = escapeRequests[_sponsor];
        newRequests.push(_ship);
        escapeRequestsIndexes[_sponsor][_ship] = newRequests.length;
      }

      ship.escapeRequestedTo = _sponsor;
      ship.escapeRequested = _isEscaping;
    }

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
      external
      pure
      returns (Class _class)
    {
      if (_ship < 256) return Class.Galaxy;
      if (_ship < 65536) return Class.Star;
      return Class.Planet;
    }
}
