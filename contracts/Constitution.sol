//  the urbit ethereum constitution

pragma solidity 0.4.24;

import './ConstitutionBase.sol';
import './Claims.sol';
import './ERC165Mapping.sol';
import './interfaces/ERC721Receiver.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import 'openzeppelin-solidity/contracts/AddressUtils.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

//  Constitution: logic for interacting with the Urbit ledger
//
//    This contract is the point of entry for all operations on the Urbit
//    ledger as stored in the Ships contract. The functions herein are
//    responsible for performing all necessary business logic.
//    Examples of such logic include verifying permissions of the caller
//    and ensuring a requested change is actually valid.
//    Ship owners can always operate on their own ships. Ethereum addresses
//    can also perform specific operations if they've been given the
//    appropriate permissions. (For example, managers for general management,
//    spawn proxies for spawning child ships, etc.)
//
//    This contract uses external contracts (Ships, Polls) for data storage
//    so that it itself can easily be replaced in case its logic needs to
//    be changed. In other words, it can be upgraded. It does this by passing
//    ownership of the data contracts to a new Constitution contract.
//
//    Because of this, it is advised for clients to not store this contract's
//    address directly, but rather ask the Ships contract for its owner
//    attribute to ensure transactions get sent to the latest Constitution.
//
//    Upgrading happens based on polls held by the senate (galaxy owners).
//    Through this contract, the senate can submit proposals, opening polls
//    for the senate to cast votes on. These proposals can be either hashes
//    of documents or addresses of new Constitutions.
//    If a constitution proposal gains majority, this contract will transfer
//    ownership of the data storage contracts to that address, so that it may
//    operate on the date they contain. This contract will selfdestruct at
//    the end of the upgrade process.
//
//    This contract implements the ERC721 interface for non-fungible tokens,
//    allowing ships to be managed using generic clients that support the
//    standard. It also implements ERC165 to allow this to be discovered.
//
contract Constitution is ConstitutionBase, ERC165Mapping, ERC721Metadata
{
  using SafeMath for uint256;
  using AddressUtils for address;

  //  Transfer: This emits when ownership of any NFT changes by any mechanism.
  //            This event emits when NFTs are created (`from` == 0) and
  //            destroyed (`to` == 0). At the time of any transfer, the approved
  //            address for that NFT (if any) is reset to none.
  //
  event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);

  //  Approval: This emits when the approved address for an NFT is changed or
  //            reaffirmed. The zero address indicates there is no approved
  //            address. When a Transfer event emits, this also indicates that
  //            the approved address for that NFT (if any) is reset to none.
  event Approval(address indexed _owner, address indexed _approved,
                 uint256 _tokenId);

  //  ApprovalForAll: This emits when an operator is enabled or disabled for an
  //                  owner. The operator can manage all NFTs of the owner.
  //
  event ApprovalForAll(address indexed _owner, address indexed _operator,
                       bool _approved);

  // erc721Received: equal to:
  //        bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
  //                 which can be also obtained as:
  //        ERC721Receiver(0).onERC721Received.selector`
  bytes4 constant erc721Received = 0x150b7a02;

  //  claims: contract reference, for clearing claims on-transfer
  //
  Claims public claims;

  //  constructor(): set Urbit data addresses and signal interface support
  //
  //    Note: during first deploy, ownership of these contracts must be
  //    manually transferred to this contract after it's on the chain and
  //    its address is known.
  //
  constructor(address _previous,
              Ships _ships,
              Polls _polls,
              ENS _ensRegistry,
              string _baseEns,
              string _subEns,
              Claims _claims)
    ConstitutionBase(_previous, _ships, _polls, _ensRegistry, _baseEns, _subEns)
    public
  {
    claims = _claims;

    //  register supported interfaces for ERC165
    //
    supportedInterfaces[0x80ac58cd] = true; // ERC721
    supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
    supportedInterfaces[0x7f5828d0] = true; // ERC173 (ownership)
  }

  //
  //  ERC721 interface
  //

    //  balanceOf(): get the amount of ships owned by _owner
    //
    function balanceOf(address _owner)
      public
      view
      returns (uint256 balance)
    {
      require(0x0 != _owner);
      return ships.getOwnedShipCount(_owner);
    }

    //  ownerOf(): get the current owner of ship _tokenId
    //
    function ownerOf(uint256 _tokenId)
      public
      view
      validShipId(_tokenId)
      returns (address owner)
    {
      uint32 id = uint32(_tokenId);

      //  this will throw if the owner is the zero address,
      //  active ships always have a valid owner.
      //
      require(ships.isActive(id));

      owner = ships.getOwner(id);
    }

    //  exists(): returns true if ship _tokenId is active
    //
    function exists(uint256 _tokenId)
      public
      view
      returns (bool doesExist)
    {
      return ( (_tokenId < 4294967296) &&
               ships.isActive(uint32(_tokenId)) );
    }

    //  safeTransferFrom(): transfer ship _tokenId from _from to _to
    //
    function safeTransferFrom(address _from, address _to, uint256 _tokenId)
      public
    {
      //  transfer with empty data
      //
      safeTransferFrom(_from, _to, _tokenId, "");
    }

    //  safeTransferFrom(): transfer ship _tokenId from _from to _to,
    //                      and call recipient if it's a contract
    //
    function safeTransferFrom(address _from, address _to, uint256 _tokenId,
                              bytes _data)
      public
    {
      //  perform raw transfer
      //
      transferFrom(_from, _to, _tokenId);

      //  do the callback last to avoid re-entrancy
      //
      if (_to.isContract())
      {
        bytes4 retval = ERC721Receiver(_to)
                        .onERC721Received(msg.sender, _from, _tokenId, _data);
        //
        //  standard return idiom to confirm contract semantics
        //
        require(retval == erc721Received);
      }
    }

    //  transferFrom(): transfer ship _tokenId from _from to _to,
    //                  WITHOUT notifying recipient contract
    //
    function transferFrom(address _from, address _to, uint256 _tokenId)
      public
      validShipId(_tokenId)
    {
      uint32 id = uint32(_tokenId);
      require(ships.isOwner(id, _from));
      transferShip(id, _to, true);
    }

    //  approve(): allow _approved to transfer ownership of ship _tokenId
    //
    function approve(address _approved, uint256 _tokenId)
      public
      validShipId(_tokenId)
    {
      setTransferProxy(uint32(_tokenId), _approved);
    }

    //  setApprovalForAll(): allow or disallow _operator to transfer ownership
    //                       of ALL ships owned by :msg.sender
    //
    function setApprovalForAll(address _operator, bool _approved)
      public
    {
      require(0x0 != _operator);
      ships.setOperator(msg.sender, _operator, _approved);
      emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    //  getApproved(): get the transfer proxy for ship _tokenId
    //
    function getApproved(uint256 _tokenId)
      public
      view
      validShipId(_tokenId)
      returns (address approved)
    {
      require(ships.isActive(uint32(_tokenId)));
      return ships.getTransferProxy(uint32(_tokenId));
    }

    //  isApprovedForAll(): returns true if _operator is an operator for _owner
    //
    function isApprovedForAll(address _owner, address _operator)
      public
      view
      returns (bool result)
    {
      return ships.isOperator(_owner, _operator);
    }

  //
  //  ERC721Metadata interface
  //

    function name()
      public
      view
      returns (string)
    {
      return "Urbit Ship";
    }

    function symbol()
      public
      view
      returns (string)
    {
      return "URS";
    }

    //  tokenURI(): produce a URL to a standard JSON file
    //
    function tokenURI(uint256 _tokenId)
      public
      view
      validShipId(_tokenId)
      returns (string _tokenURI)
    {
      _tokenURI = "https://eth.urbit.org/erc721/0000000000.json";
      bytes memory _tokenURIBytes = bytes(_tokenURI);
      _tokenURIBytes[29] = byte(48+(_tokenId / 1000000000) % 10);
      _tokenURIBytes[30] = byte(48+(_tokenId / 100000000) % 10);
      _tokenURIBytes[31] = byte(48+(_tokenId / 10000000) % 10);
      _tokenURIBytes[32] = byte(48+(_tokenId / 1000000) % 10);
      _tokenURIBytes[33] = byte(48+(_tokenId / 100000) % 10);
      _tokenURIBytes[34] = byte(48+(_tokenId / 10000) % 10);
      _tokenURIBytes[35] = byte(48+(_tokenId / 1000) % 10);
      _tokenURIBytes[36] = byte(48+(_tokenId / 100) % 10);
      _tokenURIBytes[37] = byte(48+(_tokenId / 10) % 10);
      _tokenURIBytes[38] = byte(48+(_tokenId / 1) % 10);
    }

  //
  //  Urbit functions for all ships
  //

    //  setManagementProxy(): configure the management proxy for _ship
    //
    //    The management proxy may perform "reversible" operations on
    //    behalf of the owner. This includes public key configuration and
    //    operations relating to sponsorship.
    //
    function setManagementProxy(uint32 _ship, address _manager)
      external
      activeShipOwner(_ship)
    {
      ships.setManagementProxy(_ship, _manager);
    }

    //  configureKeys(): configure _ship with Urbit public keys _encryptionKey,
    //                   _authenticationKey, and corresponding
    //                   _cryptoSuiteVersion, incrementing the ship's
    //                   continuity number if needed
    //
    function configureKeys(uint32 _ship,
                           bytes32 _encryptionKey,
                           bytes32 _authenticationKey,
                           uint32 _cryptoSuiteVersion,
                           bool _discontinuous)
      external
      activeShipManager(_ship)
    {
      if (_discontinuous)
      {
        ships.incrementContinuityNumber(_ship);
      }
      ships.setKeys(_ship,
                    _encryptionKey,
                    _authenticationKey,
                    _cryptoSuiteVersion);
    }

    //  spawn(): spawn _ship, giving ownership to _target
    //
    //    Requirements:
    //    - _ship must not be active,
    //    - _ship must not be a planet with a galaxy prefix,
    //    - _ship's prefix must be booted and under its spawn limit,
    //    - :msg.sender must be either the owner of _ship's prefix,
    //      or an authorized spawn proxy for it.
    //
    function spawn(uint32 _ship, address _target)
      external
    {
      //  only currently unowned (and thus also inactive) ships can be spawned
      //
      require(ships.isOwner(_ship, 0x0));

      //  prefix: half-width prefix of _ship
      //
      uint16 prefix = ships.getPrefix(_ship);

      //  only allow spawning of ships of the class directly below the prefix
      //
      //    this is possible because of how the address space works,
      //    but supporting it introduces complexity through broken assumptions.
      //
      //    example:
      //    0x0000.0000 - galaxy zero
      //    0x0000.0100 - the first star of galaxy zero
      //    0x0001.0100 - the first planet of the first star
      //    0x0001.0000 - the first planet of galaxy zero
      //
      require( (uint8(ships.getShipClass(prefix)) + 1) ==
               uint8(ships.getShipClass(_ship)) );

      //  prefix ship must be live and able to spawn
      //
      require( (ships.hasBeenBooted(prefix)) &&
               ( ships.getSpawnCount(prefix) <
                 getSpawnLimit(prefix, block.timestamp) ) );

      //  the owner of a prefix can always spawn its children;
      //  other addresses need explicit permission (the role
      //  of "spawnProxy" in the Ships contract)
      //
      require( ships.isOwner(prefix, msg.sender) ||
               ships.isSpawnProxy(prefix, msg.sender) );

      //  if the caller is spawning the ship to themselves,
      //  assume it knows what it's doing and resolve right away
      //
      if (msg.sender == _target)
      {
        doSpawn(_ship, _target, true, 0x0);
      }
      //
      //  when sending to a "foreign" address, enforce a withdraw pattern
      //  making the _ship parent's owner the _ship owner in the mean time
      //
      else
      {
        doSpawn(_ship, _target, false, ships.getOwner(prefix));
      }
    }

    function doSpawn( uint32 _ship,
                      address _target,
                      bool _direct,
                      address _holder )
      internal
    {
      //  register the spawn for _ship's prefix, incrementing spawn count
      //
      ships.registerSpawned(_ship);

      //  if the spawn is _direct, assume _target knows what they're doing
      //  and resolve right away
      //
      if (_direct)
      {
        //  make the ship active and set its new owner
        //
        ships.activateShip(_ship);
        ships.setOwner(_ship, _target);

        emit Transfer(0x0, _target, uint256(_ship));
      }
      //
      //  when spawning indirectly, enforce a withdraw pattern by approving
      //  the _target for transfer of the _ship instead.
      //  we make the _holder the owner of this _ship in the mean time,
      //  so that it may cancel the transfer (un-approve) if _target flakes.
      //  we don't make _ship active yet, because it still doesn't really
      //  belong to anyone.
      //
      else
      {
        //  have _holder hold on to the ship while _target gets to transfer
        //  ownership of it
        //
        ships.setOwner(_ship, _holder);
        ships.setTransferProxy(_ship, _target);

        emit Transfer(0x0, _holder, uint256(_ship));
        emit Approval(_holder, _target, uint256(_ship));
      }
    }

    //  getSpawnLimit(): returns the total number of children the ship _ship
    //                   is allowed to spawn at datetime _time.
    //
    function getSpawnLimit(uint32 _ship, uint256 _time)
      public
      view
      returns (uint32 limit)
    {
      Ships.Class class = ships.getShipClass(_ship);

      if ( class == Ships.Class.Galaxy )
      {
        return 255;
      }
      else if ( class == Ships.Class.Star )
      {
        //  in 2018, stars may spawn at most 1024 planets. this limit doubles
        //  for every subsequent year.
        //
        //    Note: 1514764800 corresponds to 2018-01-01
        //
        uint256 yearsSince2018 = (_time - 1514764800) / 365 days;
        if (yearsSince2018 < 6)
        {
          limit = uint32( 1024 * (2 ** yearsSince2018) );
        }
        else
        {
          limit = 65535;
        }
        return limit;
      }
      else  //  class == Ships.Class.Planet
      {
        //  planets can create moons, but moons aren't on the chain
        //
        return 0;
      }
    }

    //  setSpawnProxy(): give _spawnProxy the right to spawn ships
    //                   with the prefix _prefix
    //
    function setSpawnProxy(uint16 _prefix, address _spawnProxy)
      external
      activeShipOwner(_prefix)
    {
      ships.setSpawnProxy(_prefix, _spawnProxy);
    }

    //  transferShip(): transfer _ship to _target, clearing all permissions
    //                  data and keys if _reset is true
    //
    //    Note: the _reset flag is useful when transferring the ship to
    //    a recipient who doesn't trust the previous owner.
    //
    //    Requirements:
    //    - :msg.sender must be either _ship's current owner, authorized
    //      to transfer _ship, or authorized to transfer the current
    //      owner's ships.
    //    - _target must not be the zero address.
    //
    function transferShip(uint32 _ship, address _target, bool _reset)
      public
    {
      //  old: current ship owner
      //
      address old = ships.getOwner(_ship);

      //  transfer is legitimate if the caller is the old owner, or
      //  has operator or transfer rights
      //
      require((old == msg.sender)
              || ships.isOperator(old, msg.sender)
              || ships.isTransferProxy(_ship, msg.sender));

      //  if the ship wasn't active yet, that means transferring it
      //  is part of the "spawn" flow, so we need to activate it
      //
      if ( !ships.isActive(_ship) )
      {
        ships.activateShip(_ship);
      }

      //  if the owner would actually change, change it
      //
      //    the only time this deliberately wouldn't be the case is when a
      //    parent ship wants to activate a spawned but untransferred child.
      //
      if ( !ships.isOwner(_ship, _target) )
      {
        ships.setOwner(_ship, _target);

        //  according to ERC721, the transferrer gets cleared during every
        //  Transfer event
        //
        ships.setTransferProxy(_ship, 0);

        emit Transfer(old, _target, uint256(_ship));
      }

      //  reset sensitive data -- are transferring the
      //  ship to a new owner
      //
      if ( _reset )
      {
        //  clear the Urbit public keys and break continuity,
        //  but only if the ship has already been used
        //
        if ( ships.hasBeenBooted(_ship) )
        {
          ships.incrementContinuityNumber(_ship);
          ships.setKeys(_ship, 0, 0, 0);
        }

        //  clear management proxy
        //
        ships.setManagementProxy(_ship, 0);

        //  clear voting proxy
        //
        ships.setVotingProxy(_ship, 0);

        //  clear transfer proxy
        //
        //    in most cases this is done above, during the ownership transfer,
        //    but we might not hit that and still be expected to reset the
        //    transfer proxy.
        //    doing it a second time is a no-op in Ships.
        //
        ships.setTransferProxy(_ship, 0);

        //  clear spawning proxy
        //
        ships.setSpawnProxy(_ship, 0);

        //  clear claims
        //
        claims.clearClaims(_ship);
      }
    }

    //  setTransferProxy(): give _transferProxy the right to transfer _ship
    //
    //    Requirements:
    //    - :msg.sender must be either _ship's current owner, or be
    //      allowed to operate the current owner's ships.
    //
    function setTransferProxy(uint32 _ship, address _transferProxy)
      public
    {
      //  owner: owner of _ship
      //
      address owner = ships.getOwner(_ship);

      //  caller must be :owner, or an operator designated by the owner.
      //
      require((owner == msg.sender) || ships.isOperator(owner, msg.sender));

      //  set transferrer field in Ships contract
      //
      ships.setTransferProxy(_ship, _transferProxy);

      //  emit Approval event
      //
      emit Approval(owner, _transferProxy, uint256(_ship));
    }

    //  canEscapeTo(): true if _ship could try to escape to _sponsor
    //
    //    Note: public to help with clients
    //
    function canEscapeTo(uint32 _ship, uint32 _sponsor)
      public
      view
      returns (bool canEscape)
    {
      //  can't escape to a sponsor that hasn't been born
      //
      if ( !ships.hasBeenBooted(_sponsor) ) return false;

      //  Can only escape to a ship one class higher than ourselves,
      //  except in the special case where the escaping ship hasn't
      //  been booted yet -- in that case we may escape to ships of
      //  the same class, to support lightweight invitation chains.
      //
      //  The use case for lightweight invitations is that a planet
      //  owner should be able to invite their friends to Urbit in
      //  a two-party transaction, without a new star relationship.
      //  The lightweight invitation process works by escaping
      //  your own active, but never booted, ship, to yourself,
      //  then transferring it to your friend.
      //
      //  These planets can, in turn, sponsor other unbooted planets,
      //  so the "planet sponsorship chain" can grow to arbitrary
      //  length. Most users, especially deep down the chain, will
      //  want to improve their performance by switching to direct
      //  star sponsors eventually.
      //
      Ships.Class shipClass = ships.getShipClass(_ship);
      Ships.Class sponsorClass = ships.getShipClass(_sponsor);
      return ( //  normal hierarchical escape structure
               //
               ( (uint8(sponsorClass) + 1) == uint8(shipClass) ) ||
               //
               //  special peer escape
               //
               ( (sponsorClass == shipClass) &&
                 //
                 //  peer escape is only for ships that haven't been booted yet,
                 //  because it's only for lightweight invitation chains
                 //
                 !ships.hasBeenBooted(_ship) ) );
    }

    //  escape(): request escape from _ship to _sponsor
    //
    //    if an escape request is already active, this overwrites
    //    the existing request
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _ship,
    //    - _ship must be able to escape to _sponsor according to canEscapeTo().
    //
    function escape(uint32 _ship, uint32 _sponsor)
      external
      activeShipManager(_ship)
    {
      require(canEscapeTo(_ship, _sponsor));
      ships.setEscapeRequest(_ship, _sponsor);
    }

    //  cancelEscape(): cancel the currently set escape for _ship
    //
    function cancelEscape(uint32 _ship)
      external
      activeShipManager(_ship)
    {
      ships.cancelEscape(_ship);
    }

    //  adopt(): as the _sponsor, accept the _ship
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _ship's requested sponsor.
    //
    function adopt(uint32 _ship)
      external
    {
      require( ships.isEscaping(_ship) &&
               ships.canManage(ships.getEscapeRequest(_ship), msg.sender) );

      //  _sponsor becomes _ship's sponsor
      //  its escape request is reset to "not escaping"
      //
      ships.doEscape(_ship);
    }

    //  reject(): as the _sponsor, deny the _ship's request
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _ship's requested sponsor.
    //
    function reject(uint32 _ship)
      external
    {
      require( ships.isEscaping(_ship) &&
               ships.canManage(ships.getEscapeRequest(_ship), msg.sender) );

      //  reset the _ship's escape request to "not escaping"
      //
      ships.cancelEscape(_ship);
    }

    //  detach(): as the _sponsor, stop sponsoring the _ship
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _ship's current sponsor.
    //
    function detach(uint32 _ship)
      external
    {
      require( ships.hasSponsor(_ship) &&
               ships.canManage(ships.getSponsor(_ship), msg.sender) );

      //  signal that _sponsor no longer supports _ship
      //
      ships.loseSponsor(_ship);
    }

  //
  //  Poll actions
  //

    //  setVotingProxy(): configure the voting proxy for _ship
    //
    //    the voting proxy is allowed to start polls and cast votes
    //    on the ship's behalf.
    //
    function setVotingProxy(uint8 _ship, address _voter)
      external
      activeShipOwner(_ship)
    {
      ships.setVotingProxy(_ship, _voter);
    }

    //  startConstitutionPoll(): as _galaxy, start a poll for the constitution
    //                       upgrade _proposal
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _galaxy,
    //    - the _proposal must expect to be upgraded from this specific
    //      contract, as indicated by its previousConstitution attribute.
    //
    function startConstitutionPoll(uint8 _galaxy, ConstitutionBase _proposal)
      external
      activeShipVoter(_galaxy)
    {
      //  ensure that the upgrade target expects this contract as the source
      //
      require(_proposal.previousConstitution() == address(this));
      polls.startConstitutionPoll(_proposal);
    }

    //  startDocumentPoll(): as _galaxy, start a poll for the _proposal
    //
    function startDocumentPoll(uint8 _galaxy, bytes32 _proposal)
      external
      activeShipVoter(_galaxy)
    {
      polls.startDocumentPoll(_proposal);
    }

    //  castConstitutionVote(): as _galaxy, cast a _vote on the constitution
    //                          upgrade _proposal
    //
    //    _vote is true when in favor of the proposal, false otherwise
    //
    //    If this vote results in a majority for the _proposal, it will
    //    be upgraded to immediately.
    //
    function castConstitutionVote(uint8 _galaxy,
                                  ConstitutionBase _proposal,
                                  bool _vote)
      external
      activeShipVoter(_galaxy)
    {
      //  majority: true if the vote resulted in a majority, false otherwise
      //
      bool majority = polls.castConstitutionVote(_galaxy, _proposal, _vote);

      //  if a majority is in favor of the upgrade, it happens as defined
      //  in the constitution base contract
      //
      if (majority)
      {
        upgrade(_proposal);
      }
    }

    //  castDocumentVote(): as _galaxy, cast a _vote on the _proposal
    //
    //    _vote is true when in favor of the proposal, false otherwise
    //
    function castDocumentVote(uint8 _galaxy, bytes32 _proposal, bool _vote)
      external
      activeShipVoter(_galaxy)
    {
      polls.castDocumentVote(_galaxy, _proposal, _vote);
    }

    //  updateConstitutionPoll(): check whether the _proposal has achieved
    //                            majority, upgrading to it if it has
    //
    function updateConstitutionPoll(ConstitutionBase _proposal)
      external
    {
      //  majority: true if the poll ended in a majority, false otherwise
      //
      bool majority = polls.updateConstitutionPoll(_proposal);

      //  if a majority is in favor of the upgrade, it happens as defined
      //  in the constitution base contract
      //
      if (majority)
      {
        upgrade(_proposal);
      }
    }

    //  updateDocumentPoll(): check whether the _proposal has achieved majority
    //
    //    Note: the polls contract publicly exposes the function this calls,
    //    but we offer it in the constitution interface as a convenience
    //
    function updateDocumentPoll(bytes32 _proposal)
      external
    {
      polls.updateDocumentPoll(_proposal);
    }

  //
  //  Contract owner operations
  //

    //  createGalaxy(): grant _target ownership of the _galaxy and register
    //                  it for voting
    //
    function createGalaxy(uint8 _galaxy, address _target)
      external
      onlyOwner
    {
      //  only currently unowned (and thus also inactive) galaxies can be
      //  created, and only to non-zero addresses
      //
      require( ships.isOwner(_galaxy, 0x0) &&
               0x0 != _target );

      //  new galaxy means a new registered voter
      //
      polls.incrementTotalVoters();

      //  if the caller is sending the galaxy to themselves,
      //  assume it knows what it's doing and resolve right away
      //
      if (msg.sender == _target)
      {
        doSpawn(_galaxy, _target, true, 0x0);
      }
      //
      //  when sending to a "foreign" address, enforce a withdraw pattern,
      //  making the caller the owner in the mean time
      //
      else
      {
        doSpawn(_galaxy, _target, false, msg.sender);
      }
    }

    function setDnsDomains(string _primary, string _secondary, string _tertiary)
      external
      onlyOwner
    {
      ships.setDnsDomains(_primary, _secondary, _tertiary);
    }

  //
  //  Function modifiers for this contract
  //

    //  validShipId(): require that _id is a valid ship
    //
    modifier validShipId(uint256 _id)
    {
      require(_id < 4294967296);
      _;
    }

    modifier activeShipVoter(uint32 _ship)
    {
      require( ships.canVoteAs(_ship, msg.sender) &&
               ships.isActive(_ship) );
      _;
    }
}
