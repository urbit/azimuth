//  the urbit ethereum constitution

pragma solidity 0.4.21;

import './ConstitutionBase.sol';
import './ERC165Mapping.sol';
import './interfaces/ERC721.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

//  Constitution: logic for interacting with the Urbit ledger
//
//    This contract is the point of entry for all operations on the Urbit
//    ledger as stored in the Ships contract. The functions herein are
//    responsible for performing all necessary business logic.
//    Examples of such logic include verifying permissions of the caller
//    and ensuring a requested change is actually valid.
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
//    for the senate to cast votes on. These proposals can be either abstract
//    (hashes of documents) or concrete (addresses of new Constitutions).
//    If a concrete proposal gains majority, this contract will transfer
//    ownership of the data storage contracts to that address, so that it may
//    operate on the date they contain. This contract will selfdestruct at
//    the end of the upgrade process.
//
//    This contract implements the ERC721 interface for non-fungible tokens,
//    allowing ships to be managed using generic clients that support the
//    standard. It also implements ERC165 to allow this to be discovered.
//
contract Constitution is ConstitutionBase, ERC165Mapping, ERC721
                         //TODO: fix this :-)
                         //
                         // including more interfaces causes the contract to
                         // not deploy properly, so we only temporarily
                         // enable these during compilation
                         //, ERC721Metadata, ERC721Enumerable
{
  using SafeMath for uint256;

  event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
  event Approval(address indexed _owner, address indexed _approved,
                 uint256 _tokenId);
  event ApprovalForAll(address indexed _owner, address indexed _operator,
                       bool _approved);

  //  ERC721 metadata
  //
  string constant public name = "Urbit Ship";
  string constant public symbol = "URS";
  uint256 constant public totalSupply = 4294967296;

  //  Constitution(): set Urbit data addresses and signal interface support
  //
  //    Note: during first deploy, ownership of these contracts must be
  //    manually transferred to this contract after it's on the chain and
  //    its address is known.
  //
  function Constitution(address _previous, Ships _ships, Polls _polls)
    ConstitutionBase(_previous, _ships, _polls)
    public
  {
    //  register supported interfaces for ERC165
    //
    supportedInterfaces[0x6466353c] = true; // ERC721
    supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
    supportedInterfaces[0x780e9d63] = true; // ERC721Enumerable
  }

  //
  //  ERC721 interface
  //

    function balanceOf(address _owner)
      external
      view
      returns (uint256 balance)
    {
      return ships.getOwnedShipCount(_owner);
    }

    function ownerOf(uint256 _tokenId)
      external
      view
      shipId(_tokenId)
      returns (address owner)
    {
      uint32 id = uint32(_tokenId);
      require(ships.isActive(id));
      return ships.getOwner(id);
    }

    //  safeTransferFrom(): transfer ship _tokenId from _from to _to
    //
    function safeTransferFrom(address _from, address _to, uint256 _tokenId)
      external
    {
      //  transfer with empty data
      //
      safeTransferFrom(_from, _to, _tokenId, "");
    }

    //  safeTransferFrom(): transfer ship _tokenId from _from to _to,
    //                      and call recipient if it's a contract
    //
    function safeTransferFrom(address _from, address _to, uint256 _tokenId,
                              bytes data)
      public
    {
      //  perform raw transfer
      //
      transferFrom(_from, _to, _tokenId);

      //  do the callback last to avoid re-entrancy
      //
      {
        uint256 codeSize;

        //  eth idiom to check if _to is a contract
        //
        assembly { codeSize := extcodesize(_to) }
        if (codeSize > 0)
        {
          bytes4 retval = ERC721TokenReceiver(_to)
                          .onERC721Received(_from, _tokenId, data);
          //
          //  standard return idiom to confirm contract semantics
          //
          require(retval ==
                  bytes4(keccak256("onERC721Received(address,uint256,bytes)")));
        }
      }
    }

    //  transferFrom(): transfer ship _tokenId from _from to _to,
    //                  WITHOUT notifying recipient contract
    //
    function transferFrom(address _from, address _to, uint256 _tokenId)
      public
      shipId(_tokenId)
    {
      uint32 id = uint32(_tokenId);
      require(ships.isOwner(id, _from));
      transferShip(id, _to, true);
    }

    //  approve(): allow _approved to transfer ownership of ship _tokenId
    //
    function approve(address _approved, uint256 _tokenId)
      external
      shipId(_tokenId)
    {
      setTransferProxy(uint32(_tokenId), _approved);
    }

    //  setApprovalForAll(): allow or disallow _operator to transfer ownership
    //                       of ALL ships owned by :msg.sender
    //
    function setApprovalForAll(address _operator, bool _approved)
      external
    {
      ships.setOperator(msg.sender, _operator, _approved);
      emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId)
      external
      view
      shipId(_tokenId)
      returns (address approved)
    {
      return ships.getTransferProxy(uint32(_tokenId));
    }

    function isApprovedForAll(address _owner, address _operator)
      external
      view
      returns (bool result)
    {
      return ships.isOperator(_owner, _operator);
    }

  //
  //  ERC721Enumerable interface
  //

    //  tokenByIndex(): translate _index (token identity) into ship number
    //
    function tokenByIndex(uint256 _index)
      external
      pure
      returns (uint256)
    {
      return _index;
    }

    //  tokenOfOwnerByIndex(): return the _indexth ship owned by _owner
    //
    //    Note: these indexes are not stable across time, as ownership
    //    lists can change.
    //
    function tokenOfOwnerByIndex(address _owner, uint256 _index)
      external
      view
      returns (uint256 _tokenId)
    {
      return ships.getOwnedShipAtIndex(_owner, _index);
    }

  //
  //  ERC721Metadata interface
  //

    //  tokenURI(): produce a URL to a standard JSON file
    //
    function tokenURI(uint256 _tokenId)
      external
      pure
      shipId(_tokenId)
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

    //  configureKeys(): configure _ship with Urbit public keys _encryptionKey
    //                   and _authenticationKey
    //
    function configureKeys(uint32 _ship,
                           bytes32 _encryptionKey,
                           bytes32 _authenticationKey)
      external
      shipOwner(_ship)
    {
      ships.setKeys(_ship, _encryptionKey, _authenticationKey);
    }

    //  spawn(): spawn _ship, giving ownership to _target
    //
    //    Requirements:
    //    - _ship must not be active,
    //    - _ship must not be a planet with a galaxy prefix,
    //    - _ship's prefix must be active and under its spawn limit,
    //    - :msg.sender must be either the owner of _ship's prefix,
    //      or an authorized spawn proxy for it.
    //
    function spawn(uint32 _ship,
                   address _target)
      external
    {
      //  only currently inactive ships can be spawned
      //
      require(!ships.isActive(_ship));

      //  prefix: half-width prefix of _ship
      //
      uint16 prefix = ships.getPrefix(_ship);

      //  prevent galaxies from spawning planets
      //
      require( (uint8(ships.getShipClass(prefix)) + 1) ==
               uint8(ships.getShipClass(_ship)) );

      //  prefix ship must be live and able to spawn
      //
      require( (ships.hasBeenBooted(prefix)) &&
               (ships.getSpawnCount(prefix) <
                getSpawnLimit(prefix, block.timestamp)) );

      //  the owner of a prefix can always spawn its children;
      //  other addresses need explicit permission (the role
      //  of "spawnProxy" in the Ships contract)
      //
      require(ships.isOwner(prefix, msg.sender)
              || ships.isSpawnProxy(prefix, msg.sender));

      //  set the new owner of the ship and make it active
      //
      ships.setOwner(_ship, _target);
      ships.setActive(_ship);
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

      if ( class == Ships.Class.Planet )
      {
        //
        //  planets can create moons, but moons aren't on the chain
        //
        return 0;
      }
      if ( class == Ships.Class.Galaxy )
      {
        return 255;
      }
      if ( class == Ships.Class.Star )
      {
        //  in 2018, stars may spawn at most 1024 planets. this limit doubles
        //  for every subsequent year.
        //
        //    Note: 1514764800 corresponds to 2018-01-01
        //
        uint256 yearsSince2018 = (_time - 1514764800) / 1 years;
        if (yearsSince2018 > 6)
        {
          yearsSince2018 = 6;
        }
        limit = 1024;
        while (yearsSince2018 > 0)
        {
          limit = limit * 2;
          yearsSince2018--;
        }
        if (limit > 65535)
        {
          limit = 65535;
        }
        return limit;
      }
    }

    //  setSpawnProxy(): give _spawnProxy the right to spawn ships
    //                   with the prefix _ship
    //
    function setSpawnProxy(uint16 _ship, address _spawnProxy)
      external
      shipOwner(_ship)
      active(_ship)
    {
      ships.setSpawnProxy(_ship, _spawnProxy);
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

      //  reset sensitive data --  are transferring the
      //  ship to a new owner
      //
      if ( _reset )
      {
        //  clear Urbit public keys
        //
        ships.setKeys(_ship, 0, 0);

        //  clear transfer proxy
        //
        ships.setTransferProxy(_ship, 0);

        //  clear spawning proxy
        //
        ships.setSpawnProxy(_ship, 0);
      }
      ships.setOwner(_ship, _target);

      //  emit Transfer event
      //
      emit Transfer(old, _target, uint256(_ship));
    }

    //  setTransferProxy(): give _transferProxy the right to transfer _ship
    //
    //    Requirements:
    //    - :msg.sender must be either _ship's current owner, or be
    //      allowed to manage the current owner's ships.
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

      //  We must escape to a sponsor of the same class, except in
      //  the special case where the escaping ship hasn't been
      //  born yet -- to support lightweight invitation chains.
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
      shipOwner(_ship)
    {
      require(canEscapeTo(_ship, _sponsor));
      ships.setEscape(_ship, _sponsor);
    }

    //  cancelEscape(): cancel the currently set escape for _ship
    //
    function cancelEscape(uint32 _ship)
      external
      shipOwner(_ship)
    {
      ships.cancelEscape(_ship);
    }

    //  adopt(): as the _sponsor, accept the _escapee
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _sponsor,
    //    - _escapee must currently be trying to escape to _sponsor.
    //
    function adopt(uint32 _sponsor, uint32 _escapee)
      external
      shipOwner(_sponsor)
    {
      require(ships.isEscape(_escapee, _sponsor));

      //  _sponsor becomes _escapee's sponsor
      //  its escape request is reset to "not escaping"
      //
      ships.doEscape(_escapee);
    }

    //  reject(): as the _sponsor, deny the _escapee's request
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _sponsor,
    //    - _escapee must currently be trying to escape to _sponsor.
    //
    function reject(uint32 _sponsor, uint32 _escapee)
      external
      shipOwner(_sponsor)
    {
      require(ships.isEscape(_escapee, _sponsor));

      //  reset the _escapee's escape request to "not escaping"
      //
      ships.cancelEscape(_escapee);
    }

  //
  //  Poll actions
  //

    //  startConcretePoll(): as _galaxy, start a poll for the constitution
    //                       upgrade _proposal
    //
    //    Requirements:
    //    - :msg.sender must be the owner of _galaxy,
    //    - the _proposal must expect to be upgraded from this specific
    //      contract, as indicated by its previousConstitution attribute.
    //
    function startConcretePoll(uint8 _galaxy, ConstitutionBase _proposal)
      external
      shipOwner(_galaxy)
    {
      //  ensure that the upgrade target expects this contract as the source
      //
      require(_proposal.previousConstitution() == address(this));
      polls.startConcretePoll(_proposal);
    }

    //  startAbstractPoll(): as _galaxy, start a poll for the _proposal
    //
    function startAbstractPoll(uint8 _galaxy, bytes32 _proposal)
      external
      shipOwner(_galaxy)
    {
      polls.startAbstractPoll(_proposal);
    }

    //  castConcreteVote(): as _galaxy, cast a _vote on the constitution
    //                      upgrade _proposal
    //
    //    _vote is true when in favor of the proposal, false otherwise
    //
    //    If this vote results in a majority for the _proposal, it will
    //    be upgraded to immediately.
    //
    function castConcreteVote(uint8 _galaxy,
                              ConstitutionBase _proposal,
                              bool _vote)
      external
      shipOwner(_galaxy)
    {
      //  majority: true if the vote resulted in a majority, false otherwise
      //
      bool majority = polls.castConcreteVote(_galaxy, _proposal, _vote);

      //  if a majority is in favor of the upgrade, it happens as defined
      //  in the constitution base contract
      //
      if (majority)
      {
        upgrade(_proposal);
      }
    }

    //  castAbstractVote(): as _galaxy, cast a _vote on the _proposal
    //
    //    _vote is true when in favor of the proposal, false otherwise
    //
    function castAbstractVote(uint8 _galaxy, bytes32 _proposal, bool _vote)
      external
      shipOwner(_galaxy)
    {
      polls.castAbstractVote(_galaxy, _proposal, _vote);
    }

    //  updateConcretePoll(): check whether the _proposal has achieved majority,
    //                        upgrading to it if it has
    //
    function updateConcretePoll(ConstitutionBase _proposal)
      external
    {
      //  majority: true if the poll ended in a majority, false otherwise
      //
      bool majority = polls.updateConcretePoll(_proposal);

      //  if a majority is in favor of the upgrade, it happens as defined
      //  in the constitution base contract
      //
      if (majority)
      {
        upgrade(_proposal);
      }
    }

    //  updateAbstractPoll(): check whether the _proposal has achieved majority
    //
    //    Note: the polls contract publicly exposes the function this calls,
    //    but we offer it in the constitution interface as a convenience
    //
    function updateAbstractPoll(bytes32 _proposal)
      external
    {
      polls.updateAbstractPoll(_proposal);
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
      require(!ships.isActive(_galaxy));
      polls.incrementTotalVoters();
      ships.setActive(_galaxy);
      ships.setOwner(_galaxy, _target);
    }

  //
  //  Function modifiers for this contract
  //

    //  shipId(): require that _id is a valid ship
    //
    modifier shipId(uint256 _id)
    {
      require(_id < 4294967296);
      _;
    }

    //  shipOwner(): require that :msg.sender is the owner of _ship
    //
    //    Note: ships with non-zore owners are guaranteed to be active.
    //
    modifier shipOwner(uint32 _ship)
    {
      require(ships.isOwner(_ship, msg.sender));
      _;
    }

    //  active(): require that _ship is in the active state
    //
    modifier active(uint32 _ship)
    {
      require(ships.isActive(_ship));
      _;
    }
}
