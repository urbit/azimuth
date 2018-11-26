//  the azimuth logic contract
//  https://azimuth.network

pragma solidity 0.4.24;

import './EclipticBase.sol';
import './Claims.sol';

import 'openzeppelin-solidity/contracts/introspection/SupportsInterfaceWithLookup.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Receiver.sol';
import 'openzeppelin-solidity/contracts/AddressUtils.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

//  Ecliptic: logic for interacting with the Azimuth ledger
//
//    This contract is the point of entry for all operations on the Azimuth
//    ledger as stored in the Azimuth data contract. The functions herein
//    are responsible for performing all necessary business logic.
//    Examples of such logic include verifying permissions of the caller
//    and ensuring a requested change is actually valid.
//    Point owners can always operate on their own points. Ethereum addresses
//    can also perform specific operations if they've been given the
//    appropriate permissions. (For example, managers for general management,
//    spawn proxies for spawning child points, etc.)
//
//    This contract uses external contracts (Azimuth, Polls) for data storage
//    so that it itself can easily be replaced in case its logic needs to
//    be changed. In other words, it can be upgraded. It does this by passing
//    ownership of the data contracts to a new Ecliptic contract.
//
//    Because of this, it is advised for clients to not store this contract's
//    address directly, but rather ask the Azimuth contract for its owner
//    attribute to ensure transactions get sent to the latest Ecliptic.
//    Alternatively, the ENS name ecliptic.eth will resolve to the latest
//    Ecliptic as well.
//
//    Upgrading happens based on polls held by the senate (galaxy owners).
//    Through this contract, the senate can submit proposals, opening polls
//    for the senate to cast votes on. These proposals can be either hashes
//    of documents or addresses of new Ecliptics.
//    If an ecliptic proposal gains majority, this contract will transfer
//    ownership of the data storage contracts to that address, so that it may
//    operate on the data they contain. This contract will selfdestruct at
//    the end of the upgrade process.
//
//    This contract implements the ERC721 interface for non-fungible tokens,
//    allowing points to be managed using generic clients that support the
//    standard. It also implements ERC165 to allow this to be discovered.
//
contract Ecliptic is EclipticBase, SupportsInterfaceWithLookup, ERC721Metadata
{
  using SafeMath for uint256;
  using AddressUtils for address;

  //  Transfer: This emits when ownership of any NFT changes by any mechanism.
  //            This event emits when NFTs are created (`from` == 0) and
  //            destroyed (`to` == 0). At the time of any transfer, the
  //            approved address for that NFT (if any) is reset to none.
  //
  event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);

  //  Approval: This emits when the approved address for an NFT is changed or
  //            reaffirmed. The zero address indicates there is no approved
  //            address. When a Transfer event emits, this also indicates that
  //            the approved address for that NFT (if any) is reset to none.
  //
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

  //  constructor(): set data contract addresses and signal interface support
  //
  //    Note: during first deploy, ownership of these data contracts must
  //    be manually transferred to this contract.
  //
  constructor(address _previous,
              Azimuth _azimuth,
              Polls _polls,
              Claims _claims)
    EclipticBase(_previous, _azimuth, _polls)
    public
  {
    claims = _claims;

    //  register supported interfaces for ERC165
    //
    _registerInterface(0x80ac58cd); // ERC721
    _registerInterface(0x5b5e139f); // ERC721Metadata
    _registerInterface(0x7f5828d0); // ERC173 (ownership)
  }

  //
  //  ERC721 interface
  //

    //  balanceOf(): get the amount of points owned by _owner
    //
    function balanceOf(address _owner)
      public
      view
      returns (uint256 balance)
    {
      require(0x0 != _owner);
      return azimuth.getOwnedPointCount(_owner);
    }

    //  ownerOf(): get the current owner of point _tokenId
    //
    function ownerOf(uint256 _tokenId)
      public
      view
      validPointId(_tokenId)
      returns (address owner)
    {
      uint32 id = uint32(_tokenId);

      //  this will throw if the owner is the zero address,
      //  active points always have a valid owner.
      //
      require(azimuth.isActive(id));

      return azimuth.getOwner(id);
    }

    //  exists(): returns true if point _tokenId is active
    //
    function exists(uint256 _tokenId)
      public
      view
      returns (bool doesExist)
    {
      return ( (_tokenId < 0x100000000) &&
               azimuth.isActive(uint32(_tokenId)) );
    }

    //  safeTransferFrom(): transfer point _tokenId from _from to _to
    //
    function safeTransferFrom(address _from, address _to, uint256 _tokenId)
      public
    {
      //  transfer with empty data
      //
      safeTransferFrom(_from, _to, _tokenId, "");
    }

    //  safeTransferFrom(): transfer point _tokenId from _from to _to,
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

    //  transferFrom(): transfer point _tokenId from _from to _to,
    //                  WITHOUT notifying recipient contract
    //
    function transferFrom(address _from, address _to, uint256 _tokenId)
      public
      validPointId(_tokenId)
    {
      uint32 id = uint32(_tokenId);
      require(azimuth.isOwner(id, _from));

      //  the ERC721 operator/approved address (if any) is
      //  accounted for in transferPoint()
      //
      transferPoint(id, _to, true);
    }

    //  approve(): allow _approved to transfer ownership of point
    //             _tokenId
    //
    function approve(address _approved, uint256 _tokenId)
      public
      validPointId(_tokenId)
    {
      setTransferProxy(uint32(_tokenId), _approved);
    }

    //  setApprovalForAll(): allow or disallow _operator to
    //                       transfer ownership of ALL points
    //                       owned by :msg.sender
    //
    function setApprovalForAll(address _operator, bool _approved)
      public
    {
      require(0x0 != _operator);
      azimuth.setOperator(msg.sender, _operator, _approved);
      emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    //  getApproved(): get the approved address for point _tokenId
    //
    function getApproved(uint256 _tokenId)
      public
      view
      validPointId(_tokenId)
      returns (address approved)
    {
      //NOTE  redundant, transfer proxy cannot be set for
      //      inactive points
      //
      require(azimuth.isActive(uint32(_tokenId)));
      return azimuth.getTransferProxy(uint32(_tokenId));
    }

    //  isApprovedForAll(): returns true if _operator is an
    //                      operator for _owner
    //
    function isApprovedForAll(address _owner, address _operator)
      public
      view
      returns (bool result)
    {
      return azimuth.isOperator(_owner, _operator);
    }

  //
  //  ERC721Metadata interface
  //

    //  name(): returns the name of a collection of points
    //
    function name()
      external
      view
      returns (string)
    {
      return "Azimuth Points";
    }

    //  symbol(): returns an abbreviates name for points
    function symbol()
      external
      view
      returns (string)
    {
      return "AZP";
    }

    //  tokenURI(): returns a URL to an ERC-721 standard JSON file
    //
    function tokenURI(uint256 _tokenId)
      public
      view
      validPointId(_tokenId)
      returns (string _tokenURI)
    {
      _tokenURI = "https://azimuth.network/erc721/0000000000.json";
      bytes memory _tokenURIBytes = bytes(_tokenURI);
      _tokenURIBytes[31] = byte(48+(_tokenId / 1000000000) % 10);
      _tokenURIBytes[32] = byte(48+(_tokenId / 100000000) % 10);
      _tokenURIBytes[33] = byte(48+(_tokenId / 10000000) % 10);
      _tokenURIBytes[34] = byte(48+(_tokenId / 1000000) % 10);
      _tokenURIBytes[35] = byte(48+(_tokenId / 100000) % 10);
      _tokenURIBytes[36] = byte(48+(_tokenId / 10000) % 10);
      _tokenURIBytes[37] = byte(48+(_tokenId / 1000) % 10);
      _tokenURIBytes[38] = byte(48+(_tokenId / 100) % 10);
      _tokenURIBytes[39] = byte(48+(_tokenId / 10) % 10);
      _tokenURIBytes[40] = byte(48+(_tokenId / 1) % 10);
    }

  //
  //  Points interface
  //

    //  configureKeys(): configure _point with network public keys
    //                   _encryptionKey, _authenticationKey,
    //                   and corresponding _cryptoSuiteVersion,
    //                   incrementing the point's continuity number if needed
    //
    function configureKeys(uint32 _point,
                           bytes32 _encryptionKey,
                           bytes32 _authenticationKey,
                           uint32 _cryptoSuiteVersion,
                           bool _discontinuous)
      external
      activePointManager(_point)
    {
      if (_discontinuous)
      {
        azimuth.incrementContinuityNumber(_point);
      }
      azimuth.setKeys(_point,
                      _encryptionKey,
                      _authenticationKey,
                      _cryptoSuiteVersion);
    }

    //  spawn(): spawn _point, then either give, or allow _target to take,
    //           ownership of _point
    //
    //    if _target is the :msg.sender, _targets owns the _point right away.
    //    otherwise, _target becomes the transfer proxy of _point.
    //
    //    Requirements:
    //    - _point must not be active
    //    - _point must not be a planet with a galaxy prefix
    //    - _point's prefix must be linked and under its spawn limit
    //    - :msg.sender must be either the owner of _point's prefix,
    //      or an authorized spawn proxy for it
    //
    function spawn(uint32 _point, address _target)
      external
    {
      //  only currently unowned (and thus also inactive) points can be spawned
      //
      require(azimuth.isOwner(_point, 0x0));

      //  prefix: half-width prefix of _point
      //
      uint16 prefix = azimuth.getPrefix(_point);

      //  only allow spawning of points of the size directly below the prefix
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
      require( (uint8(azimuth.getPointSize(prefix)) + 1) ==
               uint8(azimuth.getPointSize(_point)) );

      //  prefix point must be linked and able to spawn
      //
      require( (azimuth.hasBeenLinked(prefix)) &&
               ( azimuth.getSpawnCount(prefix) <
                 getSpawnLimit(prefix, block.timestamp) ) );

      //  the owner of a prefix can always spawn its children;
      //  other addresses need explicit permission (the role
      //  of "spawnProxy" in the Azimuth contract)
      //
      require( azimuth.canSpawnAs(prefix, msg.sender) );

      //  if the caller is spawning the point to themselves,
      //  assume it knows what it's doing and resolve right away
      //
      if (msg.sender == _target)
      {
        doSpawn(_point, _target, true, 0x0);
      }
      //
      //  when sending to a "foreign" address, enforce a withdraw pattern
      //  making the _point prefix's owner the _point owner in the mean time
      //
      else
      {
        doSpawn(_point, _target, false, azimuth.getOwner(prefix));
      }
    }

    //  doSpawn(): actual spawning logic, used in spawn(). creates _point,
    //             making the _target its owner if _direct, or making the
    //             _holder the owner and the _target the transfer proxy
    //             if not _direct.
    //
    function doSpawn( uint32 _point,
                      address _target,
                      bool _direct,
                      address _holder )
      internal
    {
      //  register the spawn for _point's prefix, incrementing spawn count
      //
      azimuth.registerSpawned(_point);

      //  if the spawn is _direct, assume _target knows what they're doing
      //  and resolve right away
      //
      if (_direct)
      {
        //  make the point active and set its new owner
        //
        azimuth.activatePoint(_point);
        azimuth.setOwner(_point, _target);

        emit Transfer(0x0, _target, uint256(_point));
      }
      //
      //  when spawning indirectly, enforce a withdraw pattern by approving
      //  the _target for transfer of the _point instead.
      //  we make the _holder the owner of this _point in the mean time,
      //  so that it may cancel the transfer (un-approve) if _target flakes.
      //  we don't make _point active yet, because it still doesn't really
      //  belong to anyone.
      //
      else
      {
        //  have _holder hold on to the _point while _target gets to transfer
        //  ownership of it
        //
        azimuth.setOwner(_point, _holder);
        azimuth.setTransferProxy(_point, _target);

        emit Transfer(0x0, _holder, uint256(_point));
        emit Approval(_holder, _target, uint256(_point));
      }
    }

    //  transferPoint(): transfer _point to _target, clearing all permissions
    //                   data and keys if _reset is true
    //
    //    Note: the _reset flag is useful when transferring the point to
    //    a recipient who doesn't trust the previous owner.
    //
    //    Requirements:
    //    - :msg.sender must be either _point's current owner, authorized
    //      to transfer _point, or authorized to transfer the current
    //      owner's points (as in ERC721's operator)
    //    - _target must not be the zero address
    //
    function transferPoint(uint32 _point, address _target, bool _reset)
      public
    {
      //  transfer is legitimate if the caller is the current owner, or
      //  an operator for the current owner, or the _point's transfer proxy
      //
      require(azimuth.canTransfer(_point, msg.sender));

      //  if the point wasn't active yet, that means transferring it
      //  is part of the "spawn" flow, so we need to activate it
      //
      if ( !azimuth.isActive(_point) )
      {
        azimuth.activatePoint(_point);
      }

      //  if the owner would actually change, change it
      //
      //    the only time this deliberately wouldn't be the case is when a
      //    prefix owner wants to activate a spawned but untransferred child.
      //
      if ( !azimuth.isOwner(_point, _target) )
      {
        //  remember the previous owner, to be included in the Transfer event
        //
        address old = azimuth.getOwner(_point);

        azimuth.setOwner(_point, _target);

        //  according to ERC721, the approved address (here, transfer proxy)
        //  gets cleared during every Transfer event
        //
        azimuth.setTransferProxy(_point, 0);

        emit Transfer(old, _target, uint256(_point));
      }

      //  reset sensitive data
      //  used when transferring the point to a new owner
      //
      if ( _reset )
      {
        //  clear the network public keys and break continuity,
        //  but only if the point has already been linked
        //
        if ( azimuth.hasBeenLinked(_point) )
        {
          azimuth.incrementContinuityNumber(_point);
          azimuth.setKeys(_point, 0, 0, 0);
        }

        //  clear management proxy
        //
        azimuth.setManagementProxy(_point, 0);

        //  clear voting proxy
        //
        azimuth.setVotingProxy(_point, 0);

        //  clear transfer proxy
        //
        //    in most cases this is done above, during the ownership transfer,
        //    but we might not hit that and still be expected to reset the
        //    transfer proxy.
        //    doing it a second time is a no-op in Azimuth.
        //
        azimuth.setTransferProxy(_point, 0);

        //  clear spawning proxy
        //
        azimuth.setSpawnProxy(_point, 0);

        //  clear claims
        //
        claims.clearClaims(_point);
      }
    }

    //  escape(): request escape as _point to _sponsor
    //
    //    if an escape request is already active, this overwrites
    //    the existing request
    //
    //    Requirements:
    //    - :msg.sender must be the owner or manager of _point,
    //    - _point must be able to escape to _sponsor as per to canEscapeTo()
    //
    function escape(uint32 _point, uint32 _sponsor)
      external
      activePointManager(_point)
    {
      require(canEscapeTo(_point, _sponsor));
      azimuth.setEscapeRequest(_point, _sponsor);
    }

    //  cancelEscape(): cancel the currently set escape for _point
    //
    function cancelEscape(uint32 _point)
      external
      activePointManager(_point)
    {
      azimuth.cancelEscape(_point);
    }

    //  adopt(): as the relevant sponsor, accept the _point
    //
    //    Requirements:
    //    - :msg.sender must be the owner or management proxy
    //      of _point's requested sponsor
    //
    function adopt(uint32 _point)
      external
    {
      require( azimuth.isEscaping(_point) &&
               azimuth.canManage( azimuth.getEscapeRequest(_point),
                                  msg.sender ) );

      //  _sponsor becomes _point's sponsor
      //  its escape request is reset to "not escaping"
      //
      azimuth.doEscape(_point);
    }

    //  reject(): as the relevant sponsor, deny the _point's request
    //
    //    Requirements:
    //    - :msg.sender must be the owner or management proxy
    //      of _point's requested sponsor
    //
    function reject(uint32 _point)
      external
    {
      require( azimuth.isEscaping(_point) &&
               azimuth.canManage( azimuth.getEscapeRequest(_point),
                                  msg.sender ) );

      //  reset the _point's escape request to "not escaping"
      //
      azimuth.cancelEscape(_point);
    }

    //  detach(): as the _sponsor, stop sponsoring the _point
    //
    //    Requirements:
    //    - :msg.sender must be the owner or management proxy
    //      of _point's current sponsor
    //
    function detach(uint32 _point)
      external
    {
      require( azimuth.hasSponsor(_point) &&
               azimuth.canManage(azimuth.getSponsor(_point), msg.sender) );

      //  signal that its sponsor no longer supports _point
      //
      azimuth.loseSponsor(_point);
    }

  //
  //  Point rules
  //

    //  getSpawnLimit(): returns the total number of children the _point
    //                   is allowed to spawn at _time.
    //
    function getSpawnLimit(uint32 _point, uint256 _time)
      public
      view
      returns (uint32 limit)
    {
      Azimuth.Size size = azimuth.getPointSize(_point);

      if ( size == Azimuth.Size.Galaxy )
      {
        return 255;
      }
      else if ( size == Azimuth.Size.Star )
      {
        //  in 2019, stars may spawn at most 1024 planets. this limit doubles
        //  for every subsequent year.
        //
        //    Note: 1546300800 corresponds to 2019-01-01
        //
        uint256 yearsSince2019 = (_time - 1546300800) / 365 days;
        if (yearsSince2019 < 6)
        {
          limit = uint32( 1024 * (2 ** yearsSince2019) );
        }
        else
        {
          limit = 65535;
        }
        return limit;
      }
      else  //  size == Azimuth.Size.Planet
      {
        //  planets can create moons, but moons aren't on the chain
        //
        return 0;
      }
    }

    //  canEscapeTo(): true if _point could try to escape to _sponsor
    //
    function canEscapeTo(uint32 _point, uint32 _sponsor)
      public
      view
      returns (bool canEscape)
    {
      //  can't escape to a sponsor that hasn't been linked
      //
      if ( !azimuth.hasBeenLinked(_sponsor) ) return false;

      //  Can only escape to a point one size higher than ourselves,
      //  except in the special case where the escaping point hasn't
      //  been linked yet -- in that case we may escape to points of
      //  the same size, to support lightweight invitation chains.
      //
      //  The use case for lightweight invitations is that a planet
      //  owner should be able to invite their friends onto an
      //  Azimuth network in a two-party transaction, without a new
      //  star relationship.
      //  The lightweight invitation process works by escaping your
      //  own active (but never linked) point to one of your own
      //  points, then transferring the point to your friend.
      //
      //  These planets can, in turn, sponsor other unlinked planets,
      //  so the "planet sponsorship chain" can grow to arbitrary
      //  length. Most users, especially deep down the chain, will
      //  want to improve their performance by switching to direct
      //  star sponsors eventually.
      //
      Azimuth.Size pointSize = azimuth.getPointSize(_point);
      Azimuth.Size sponsorSize = azimuth.getPointSize(_sponsor);
      return ( //  normal hierarchical escape structure
               //
               ( (uint8(sponsorSize) + 1) == uint8(pointSize) ) ||
               //
               //  special peer escape
               //
               ( (sponsorSize == pointSize) &&
                 //
                 //  peer escape is only for points that haven't been linked
                 //  yet, because it's only for lightweight invitation chains
                 //
                 !azimuth.hasBeenLinked(_point) ) );
    }

  //
  //  Permission management
  //

    //  setManagementProxy(): configure the management proxy for _point
    //
    //    The management proxy may perform "reversible" operations on
    //    behalf of the owner. This includes public key configuration and
    //    operations relating to sponsorship.
    //
    function setManagementProxy(uint32 _point, address _manager)
      external
      activePointOwner(_point)
    {
      azimuth.setManagementProxy(_point, _manager);
    }

    //  setSpawnProxy(): give _spawnProxy the right to spawn points
    //                   with the prefix _prefix
    //
    function setSpawnProxy(uint16 _prefix, address _spawnProxy)
      external
      activePointOwner(_prefix)
    {
      azimuth.setSpawnProxy(_prefix, _spawnProxy);
    }

    //  setVotingProxy(): configure the voting proxy for _galaxy
    //
    //    the voting proxy is allowed to start polls and cast votes
    //    on the point's behalf.
    //
    function setVotingProxy(uint8 _galaxy, address _voter)
      external
      activePointOwner(_galaxy)
    {
      azimuth.setVotingProxy(_galaxy, _voter);
    }

    //  setTransferProxy(): give _transferProxy the right to transfer _point
    //
    //    Requirements:
    //    - :msg.sender must be either _point's current owner,
    //      or be an operator for the current owner
    //
    function setTransferProxy(uint32 _point, address _transferProxy)
      public
    {
      //  owner: owner of _point
      //
      address owner = azimuth.getOwner(_point);

      //  caller must be :owner, or an operator designated by the owner.
      //
      require((owner == msg.sender) || azimuth.isOperator(owner, msg.sender));

      //  set transfer proxy field in Azimuth contract
      //
      azimuth.setTransferProxy(_point, _transferProxy);

      //  emit Approval event
      //
      emit Approval(owner, _transferProxy, uint256(_point));
    }

  //
  //  Poll actions
  //

    //  startUpgradePoll(): as _galaxy, start a poll for the ecliptic
    //                      upgrade _proposal
    //
    //    Requirements:
    //    - :msg.sender must be the owner or voting proxy of _galaxy,
    //    - the _proposal must expect to be upgraded from this specific
    //      contract, as indicated by its previousEcliptic attribute
    //
    function startUpgradePoll(uint8 _galaxy, EclipticBase _proposal)
      external
      activePointVoter(_galaxy)
    {
      //  ensure that the upgrade target expects this contract as the source
      //
      require(_proposal.previousEcliptic() == address(this));
      polls.startUpgradePoll(_proposal);
    }

    //  startDocumentPoll(): as _galaxy, start a poll for the _proposal
    //
    //    the _proposal argument is the keccak-256 hash of any arbitrary
    //    document or string of text
    //
    function startDocumentPoll(uint8 _galaxy, bytes32 _proposal)
      external
      activePointVoter(_galaxy)
    {
      polls.startDocumentPoll(_proposal);
    }

    //  castUpgradeVote(): as _galaxy, cast a _vote on the ecliptic
    //                     upgrade _proposal
    //
    //    _vote is true when in favor of the proposal, false otherwise
    //
    //    If this vote results in a majority for the _proposal, it will
    //    be upgraded to immediately.
    //
    function castUpgradeVote(uint8 _galaxy,
                              EclipticBase _proposal,
                              bool _vote)
      external
      activePointVoter(_galaxy)
    {
      //  majority: true if the vote resulted in a majority, false otherwise
      //
      bool majority = polls.castUpgradeVote(_galaxy, _proposal, _vote);

      //  if a majority is in favor of the upgrade, it happens as defined
      //  in the ecliptic base contract
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
      activePointVoter(_galaxy)
    {
      polls.castDocumentVote(_galaxy, _proposal, _vote);
    }

    //  updateUpgradePoll(): check whether the _proposal has achieved
    //                      majority, upgrading to it if it has
    //
    function updateUpgradePoll(EclipticBase _proposal)
      external
    {
      //  majority: true if the poll ended in a majority, false otherwise
      //
      bool majority = polls.updateUpgradePoll(_proposal);

      //  if a majority is in favor of the upgrade, it happens as defined
      //  in the ecliptic base contract
      //
      if (majority)
      {
        upgrade(_proposal);
      }
    }

    //  updateDocumentPoll(): check whether the _proposal has achieved majority
    //
    //    Note: the polls contract publicly exposes the function this calls,
    //    but we offer it in the ecliptic interface as a convenience
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
      require( azimuth.isOwner(_galaxy, 0x0) &&
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
      azimuth.setDnsDomains(_primary, _secondary, _tertiary);
    }

  //
  //  Function modifiers for this contract
  //

    //  validPointId(): require that _id is a valid point
    //
    modifier validPointId(uint256 _id)
    {
      require(_id < 0x100000000);
      _;
    }

    modifier activePointVoter(uint32 _point)
    {
      require( azimuth.canVoteAs(_point, msg.sender) &&
               azimuth.isActive(_point) );
      _;
    }
}
