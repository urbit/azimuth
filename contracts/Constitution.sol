// the urbit ethereum constitution
// draft

pragma solidity 0.4.18;

import './ConstitutionBase.sol';
import './ERC165Mapping.sol';
import './interfaces/ERC721.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract Constitution is ConstitutionBase, ERC165Mapping
                         // XX: fix this :-)
                         //
                         // including the following interfaces somehow causes
                         // the contract to not deploy properly. we toggle them
                         // on when developing to make sure they're satisfied,
                         // but toggle them off for tests and deploys.
                         //, ERC721, ERC721Metadata, ERC721Enumerable
{
  using SafeMath for uint256;

  event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
  event Approval(address indexed _owner, address indexed _approved,
                 uint256 _tokenId);
  event ApprovalForAll(address indexed _owner, address indexed _operator,
                       bool _approved);

  string constant public name = "Urbit Ship";
  string constant public symbol = "URS";
  uint256 constant public totalSupply = 4294967296;

  //  Constitution(): set Urbit data addresses and signal interface support
  //
  //    Note: ownership of these contracts must be transferred to this
  //    contract after it's on the chain and its contract address is known.
  //
  function Constitution(Ships _ships, Votes _votes)
    public
  {
    ships = _ships;
    votes = _votes;
    supportedInterfaces[0x6466353c] = true; // ERC721
    supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
    supportedInterfaces[0x780e9d63] = true; // ERC721Enumerable
  }

  //  ERC721 interface
  //
    function balanceOf(address _owner)
      external
      view
      returns (uint256)
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
      require(ships.hasPilot(id));
      return ships.getPilot(id);
    }

    //  safeTransferFrom(): transfer ship _tokenId from _from to _to.
    //
    function safeTransferFrom(address _from, address _to, uint256 _tokenId)
      external
    {
      //  transfer with empty data
      //
      safeTransferFrom(_from, _to, _tokenId, "");
    }

    //  safeTransferFrom(): transfer ship _tokenId from _from to _to, 
    //                      and call recipient if it's a contract.
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
      require(ships.isPilot(id, _from));
      transferShip(id, _to, true);
    }

    //  approve(): allow _approved to transfer ownership of ship _tokenId
    //
    function approve(address _approved, uint256 _tokenId)
      external
      shipId(_tokenId)
    {
      allowTransferBy(uint32(_tokenId), _approved);
    }

    //  setApprovalForAll(): allow or disallow _operator to transfer ownership
    //                       of ALL ships owned by :msg.sender
    //
    function setApprovalForAll(address _operator, bool _approved)
      external
    {
      ships.setOperator(msg.sender, _operator, _approved);
      ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId)
      external
      view
      shipId(_tokenId)
      returns (address)
    {
      return ships.getTransferrer(uint32(_tokenId));
    }

    function isApprovedForAll(address _owner, address _operator)
      external
      view
      returns (bool)
    {
      return ships.isOperator(_owner, _operator);
    }

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

  //  Urbit functions for all ships
  //
    //  spawn(): spawn _ship, giving ownership to _target, with a spawning
    //           window from _spawnStart to _spawnComplete
    //
    function spawn(uint32 _ship, 
                   address _target, 
                   uint64 _spawnStart,
                   uint64 _spawnComplete)
    {
      //  XX should not be called by planets

      //  only currently inactive ships can be spawned
      //
      require(!ships.isActive(_ship));

      //  prefix: half-width prefix of _ship
      //
      uint16 prefix = ships.getPrefix(_ship);

      //  XX: galaxies can't create planets!

      //  prefix ship must be active
      //
      require(ships.isActive(prefix));

      //  check spawning limitations
      //
      require(canSpawn(prefix, block.timestamp));

      //  the owner of a prefix can always spawn its children; 
      //  other addresses need explicit permission (the role
      //  of "spawner" in the Ships contract)
      //
      require(ships.isOwner(prefix, msg.sender)
              || ships.isSpawner(prefix, msg.sender));

      //  set the new owner of the ship
      //
      ships.setOwner(_ship, _target);

      //  set the spawning window and make the ship active
      //
      ships.setActive(_ship);
    }

    //  canSpawn(): true if _ship can create a new child
    //
    function canSpawn(uint32 _ship, uint256 _time)
      public
      view
      returns (bool can)
    {
      Class class = getClass(_ship);
      uint16 count 

      if ( class == Planet ) {
        //
        //  planets can create moons, but moons aren't on the chain
        //
        return false;
      }
      if ( class == Galaxy ) {
        return (getSpawnCount(_ship) < 255);
      }
      if ( class == Star ) {
        //  XX: limit to 1024 until end of 2018, then doubling every year
        //
        return (getSpawnCount(_ship) < 65535) 
      }
    }

    //  allowLaunchBy(): give _spawner the right to spawn children from _ship
    //
    function allowLaunchBy(uint16 _ship, address _spawner)
      external
      pilot(_ship)
      alive(_ship)
    {
      ships.setLauncher(_ship, _spawner);
    }

    //  allowTransferBy(): give _transferrer the right to transfer _ship
    //
    function allowTransferBy(uint32 _ship, address _transferrer)
      public
      unlocked(_ship)
    {
      //  owner: owner of _ship
      //
      address owner = ships.getOwner(_ship);

      //  caller must be :owner, or an operator designated by the owner.
      //
      require((owner == msg.sender) || ships.isOperator(owner, msg.sender));

      //  set transferrer field in Ships contract
      //
      ships.setTransferrer(_ship, _transferrer);

      //  send Approval event
      //
      Approval(pilot, _transferrer, uint256(_ship));
    }

    //  configureKeys(): configure _ship with Urbit public keys _encryptionKey
    //                   and _authenticationKey
    //
    function configureKeys(uint32 _ship, 
                           bytes32 _encryptionKey, 
                           bytes32 _authenticationKey)
      external
      pilot(_ship)
    {
      //  a ship cannot be booted unless it's active
      //
      require(ships.isActive());

      ships.setKey(_ship, _encryptionKey, _authenticationKey);
    }

    // transferShip(): transfer _ship to _target, clearing all sensitive data
    //                 if _reset is true
    //
    //  Note: the _reset flag is useful when transferring the ship to
    //  a recipient who doesn't trust the previous owner.
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
              || ships.isTransferrer(_ship, msg.sender));

      //  reset sensitive data --  are transferring the
      //  ship to a new owner 
      //
      if ( _reset )
      {
        //  clear Urbit public keys
        //
        ships.setKey(_ship, 0, 0);

        //  clear transfer proxy
        //
        ships.setTransferrer(_ship, 0);

        //  clear spawning proxy
        //
        ships.setSpawner(uint16(_ship), 0);
      }
      ships.setOwner(_ship, _target);

      //  post Transfer event
      //
      Transfer(old, _target, uint256(_ship));
    }

    //  rekey(): reset Urbit public keys for _ship to _encryptionKey and 
    //           _authenticationKey
    //
    function rekey(uint32 _ship, 
                   bytes32 _encryptionKey, 
                   bytes32 _authenticationKey)
      external
      owner(_ship)
      alive(_ship)
    {
      ships.setKey(_ship, _encryptionKey, _authenticationKey);
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
      //  can't escape to a sponsor if it's not active
      //
      if ( !ships.isActive(_sponsor)) return false;

      //  can't escape to a sponsor that hasn't been born
      //
      if ( 0 == ships.getRevisionNumber(_sponsor) ) return false;

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
      //  These planet sponsorship chains can grow to arbitrary length,
      //  but can only be extended at the ends.  Most users will want
      //  improve to their performance by switching to direct star sponsors.
      //
      if ( //  normal hierarchical escape structure
           //
           ((getClass(_sponsor) + 1) != getClass(_ship)) ||
           //
           //  special peer escape
           //
           ((getClass(_sponsor) == getClass(_ship)) &&
            //
            //  peer escape is only for ships that haven't been booted yet,
            //  because it's only for lightweight invitation chains
            //
            (0 == getRevisionNumber(_ship)) &&
            //
            //  the sponsor needs to have been booted already, or strange
            //  corner cases can be created
            //
            (0 != getRevisionNumber(_sponsor))) )
      {
        return false;
      }
      return true;
    }

    //  escape(): request escape from _ship to _sponsor.
    //
    function escape(uint32 _ship, uint32 _sponsor)
      external
      pilot(_ship)
    {
      require(canEscapeTo(_ship, _sponsor));
      ships.setEscape(_ship, _sponsor);
    }

    // cancel an escape.
    function cancelEscape(uint32 _ship)
      external
      pilot(_ship)
    {
      ships.cancelEscape(_ship);
    }

    // accept an escaping ship.
    function adopt(uint32 _sponsor, uint32 _child)
      external
      pilot(_sponsor)
    {
      require(ships.isEscape(_child, _sponsor));
      // _child's sponsor becomes _sponsor, its escape is reset to "no escape".
      ships.doEscape(_child);
    }

    // reject an escaping ship.
    function reject(uint32 _sponsor, uint32 _child)
      external
      pilot(_sponsor)
    {
      require(ships.isEscape(_child, _sponsor));
      // cancels the escape, making it inactive.
      ships.cancelEscape(_child);
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


  //  Function modifiers for this contract
  //
    //  shipId(): require that _id is a valid ship
    //
    modifier shipId(uint256 _id)
    {
      require(_id < 4294967296);
      _;
    }

    //  owner(): require that :msg.sender is the owner of _ship
    //
    modifier owner(uint32 _ship)
    {
      require(ships.isOwner(_ship, msg.sender));
      _;
    }

    //  active(): require that _ship is in the active state
    //
    modifier active(uint32 _ship)
    {
      require(ships.isActive(_ship)
      _;
    }
}
