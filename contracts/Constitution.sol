// the urbit ethereum constitution
// draft

pragma solidity 0.4.18;

import './ConstitutionBase.sol';
import './ERC165Mapping.sol';
import './interfaces/ERC721.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract Constitution is ConstitutionBase, ERC165Mapping
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

  // during contract construction, set the addresses of the (data) contracts we
  // rely on.
  // ownership of these contracts will need to be transfered to the constitution
  // after its contract address becomes known.
  function Constitution(Ships _ships, Votes _votes)
    public
  {
    ships = _ships;
    votes = _votes;
    supportedInterfaces[0x6466353c] = true; // ERC721
    supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
    supportedInterfaces[0x780e9d63] = true; // ERC721Enumerable
  }

  // ++erc
  // support for ERC standards

  // erc721 core

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

  function safeTransferFrom(address _from, address _to, uint256 _tokenId)
    external
  {
    safeTransferFrom(_from, _to, _tokenId, "");
  }

  function safeTransferFrom(address _from, address _to, uint256 _tokenId,
                            bytes data)
    public
  {
    transferFrom(_from, _to, _tokenId);
    // do the callback last to avoid re-entrancy.
    uint256 codeSize;
    assembly { codeSize := extcodesize(_to) }
    if (codeSize > 0)
    {
      bytes4 retval = ERC721TokenReceiver(_to)
                      .onERC721Received(_from, _tokenId, data);
      require(retval ==
              bytes4(keccak256("onERC721Received(address,uint256,bytes)")));
    }
  }

  function transferFrom(address _from, address _to, uint256 _tokenId)
    public
    shipId(_tokenId)
  {
    uint32 id = uint32(_tokenId);
    require(ships.isPilot(id, _from));
    transferShip(id, _to, true);
  }

  function approve(address _approved, uint256 _tokenId)
    external
    shipId(_tokenId)
  {
    allowTransferBy(uint32(_tokenId), _approved);
  }

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

  // erc721enumerable

  // every ship is indexes by its ship number.
  function tokenByIndex(uint256 _index)
    external
    pure
    returns (uint256)
  {
    return _index;
  }

  //TODO surely it's okay for NFTs at indices to change over time?
  function tokenOfOwnerByIndex(address _owner, uint256 _index)
    external
    view
    returns (uint256 _tokenId)
  {
    return ships.getOwnedShipAtIndex(_owner, _index);
  }

  // erc721metadata

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
    require(parent > 255 || canSpawn(parent, block.timestamp));
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
  function allowLaunchBy(uint16 _ship, address _launcher)
    external
    pilot(_ship)
    alive(_ship)
  {
    ships.setLauncher(_ship, _launcher);
  }

  // allow the given address to transfer ownership of the ship.
  function allowTransferBy(uint32 _ship, address _transferrer)
    public
    unlocked(_ship)
  {
    address pilot = ships.getPilot(_ship);
    require((pilot == msg.sender)
            || ships.isOperator(pilot, msg.sender));
    ships.setTransferrer(_ship, _transferrer);
    Approval(pilot, _transferrer, uint256(_ship));
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

  // transfer a ship to a different address. this can be done by its owner,
  // an operator of the owner, or an approved transferrer.
  function transferShip(uint32 _ship, address _target, bool _reset)
    public
  {
    address old = ships.getPilot(_ship);
    require((old == msg.sender)
            || ships.isOperator(old, msg.sender)
            || ships.isTransferrer(_ship, msg.sender));
    // we may not always want to reset the ship's key, transferrer and launcher,
    // to allow for ownership transfer without any changes. eg, when transfering
    // to ourselves.
    if (_reset)
    {
      ships.setKey(_ship, 0);
      ships.setTransferrer(_ship, 0);
      if (_ship < 65536)
      {
        ships.setLauncher(uint16(_ship), 0);
      }
    }
    ships.setPilot(_ship, _target);
    Transfer(old, _target, uint256(_ship));
  }

  // set the public key for a ship.
  function rekey(uint32 _ship, bytes32 _key)
    external
    pilot(_ship)
    alive(_ship)
  {
    ships.setKey(_ship, _key);
  }

  // we make this check publicly accessible to help with client implementation.
  function canEscapeTo(uint32 _ship, uint32 _sponsor)
    public
    view
    returns (bool canEscape)
  {
    if (!ships.isState(_sponsor, Ships.State.Living)) return false;
    if (ships.isEscaping(_sponsor)) return false;
    uint8 ourclass = getShipClass(_ship);
    uint8 class = getShipClass(_sponsor);
    // galaxies may not escape. stars may only escape to galaxies.
    // planets may escape to both stars and planets.
    if (ourclass != (class + 1)
        && !(class == 2 && ourclass == 2))
      return false;
    // but if a planet's escaping to a planet, that planet chain must be short.
    // for the non-planet case, we jump out immediately because class != 2.
    // for the planet case, we look at sponsors of sponsors.
    // in the end, we want to have found a sponsor star to end our planet chain.
    // max possible chain consists of one more planet than iteratoins below.
    // s0 <- p1 <- p2 <- p3 <- p4 <-x- p5
    uint32 chain = _sponsor;
    for (uint8 i = 0; (i < 3) && (class == 2); i++)
    {
      // if we detect circularity, bail immediately.
      if (chain == _ship) { break; }
      chain = ships.getSponsor(chain);
      class = getShipClass(chain);
    }
    // if we didn't find a star within i steps, the chain would get too long.
    return (class < 2);
  }

  // escape to a new sponsor.
  // takes effect when the new sponsor accepts the adoption.
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

  // test if the galaxy can liquify/launch another star right now.
  function canSpawn(uint16 _parent, uint256 _time)
    public
    view
    returns (bool can)
  {
    if (!ships.isState(_parent, Ships.State.Living)) { return false; }
    uint64 completed = ships.getCompleted(_parent);
    // after the completion date, they can launch everything.
    if (completed <= _time) { return true; }
    // if unlocked after completion, only the above check remains important.
    uint64 locked = ships.getLocked(_parent);
    if (completed <= locked) { return false; }
    uint256 curDiff = _time.sub(locked); // living guarantees > 0.
    uint256 totDiff = uint256(completed).sub(locked);
    // start out with 1 star, then grow over time.
    uint256 allowed = curDiff.mul(254).div(totDiff).add(1);
    uint32 children = ships.getChildren(_parent);
    return (allowed > children);
  }

  // get the class of the ship
  function getShipClass(uint32 _ship)
    public
    pure
    returns (uint8 _class)
  {
    if (_ship < 256) return 0;
    if (_ship < 65536) return 1;
    return 2;
  }

  // ++mod
  // function modifiers.

  // test if the given uint256 fits a uint32.
  modifier shipId(uint256 _id)
  {
    require(_id < 4294967296);
    _;
  }

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
