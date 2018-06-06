const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const ENSRegistry = artifacts.require('../contracts/ENSRegistry.sol');
const PublicResolver = artifacts.require('../contracts/PublicResolver.sol');

const assertRevert = require('./helpers/assertRevert');
const increaseTime = require('./helpers/increaseTime');

contract('Constitution', function([owner, user1, user2]) {
  let ships, polls, claims, ens, resolver, constit, consti2, pollTime;

  // https://github.com/ethereum/ens/blob/master/ensutils.js
  function namehash(name) {
    var node =
      '0x0000000000000000000000000000000000000000000000000000000000000000';
    if (name != '') {
      var labels = name.split(".");
      for(var i = labels.length - 1; i >= 0; i--) {
        node = web3.sha3(node + web3.sha3(labels[i]).slice(2), {encoding: 'hex'});
      }
    }
    return node.toString();
  }

  before('setting up for tests', async function() {
    pollTime = 432000;
    ships = await Ships.new();
    polls = await Polls.new(pollTime, pollTime);
    claims = await Claims.new(ships.address);
    ens = await ENSRegistry.new();
    resolver = await PublicResolver.new(ens.address);
    await ens.setSubnodeOwner(0, web3.sha3('eth'), owner);
    constit = await Constitution.new(0, ships.address, polls.address,
                                     ens.address, 'foo', 'sub',
                                     claims.address);
    assert.equal(await constit.baseNode(), namehash('foo.eth'));
    assert.equal(await constit.subNode(), namehash('sub.foo.eth'));
    await ships.transferOwnership(constit.address);
    await polls.transferOwnership(constit.address);
    await ens.setSubnodeOwner(namehash('eth'), web3.sha3('foo'), owner);
    await ens.setSubnodeOwner(namehash('foo.eth'),
                              web3.sha3('sub'),
                              owner);
    await ens.setResolver(namehash('foo.eth'), resolver.address);
    await resolver.setAddr(namehash('sub.foo.eth'), constit.address);
    await ens.setOwner(namehash('foo.eth'), constit.address);
    await ens.setOwner(namehash('sub.foo.eth'), constit.address);
  });

  it('setting dns domains', async function() {
    // can only be done by owner
    await assertRevert(constit.setDnsDomains("1", "2", "3", {from:user1}));
    await constit.setDnsDomains("1", "2", "3");
    assert.equal(await ships.dnsDomains(2), "3");
  });

  it('creating galaxies', async function() {
    // create.
    await constit.createGalaxy(0, user1);
    assert.isTrue(await ships.isActive(0));
    assert.isTrue(await ships.isOwner(0, user1));
    // can't create twice.
    await assertRevert(constit.createGalaxy(0, owner));
    // non-owner can't create.
    await assertRevert(constit.createGalaxy(1, user1, {from:user1}));
    // prep for next tests.
    await constit.createGalaxy(1, user1);
    await constit.createGalaxy(2, user1);
    assert.equal(await polls.totalVoters(), 3);
  });

  it('spawning ships', async function() {
    // can't spawn if not parent owner.
    await assertRevert(constit.spawn(256, user1, {from:user2}));
    // can't spawn if parent not live.
    await assertRevert(constit.spawn(256, user1, {from:user1}));
    await constit.configureKeys(0, 1, 2, false, {from:user1});
    // spawn child.
    await constit.spawn(256, user1, {from:user1});
    assert.isTrue(await ships.isOwner(256, user1));
    assert.isTrue(await ships.isActive(256));
    // can't launch same ship twice.
    await assertRevert(constit.spawn(256, user1, {from:user1}));
    await constit.spawn(512, user1, {from:user1});
    // check the spawn limits.
    assert.equal(await constit.getSpawnLimit(0, 0), 255);
    assert.equal(await constit.getSpawnLimit(123455, 0), 0);
    let time = Math.floor(Date.now() / 1000);
    assert.equal(await constit.getSpawnLimit(512, 1514764800), 1024); // 2018
    assert.equal(await constit.getSpawnLimit(512, 1546214400), 1024); // 2018-12
    assert.equal(await constit.getSpawnLimit(512, 1546300800), 2048); // 2019
    assert.equal(await constit.getSpawnLimit(512, 1672444800), 32768); // 2023
    assert.equal(await constit.getSpawnLimit(512, 1703980800), 65535); // 2024
    assert.equal(await constit.getSpawnLimit(512, 1735516800), 65535); // 2025
  });

  it('setting spawn proxy', async function() {
    // should not be launcher by default.
    assert.isFalse(await ships.isSpawnProxy(0, user2));
    // can't do if not owner.
    await assertRevert(constit.setSpawnProxy(0, user2, {from:user2}));
    // set up for working launch.
    await constit.setSpawnProxy(0, user2, {from:user1});
    assert.isTrue(await ships.isSpawnProxy(0, user2));
    // launch as launcher, then test revoking of rights.
    await constit.spawn(768, user1, {from:user2});
    await constit.setSpawnProxy(0, 0, {from:user1});
    assert.isFalse(await ships.isSpawnProxy(0, user2));
  });

  it('transfering ownership', async function() {
    assert.equal(await ships.getContinuityNumber(0), 0);
    // set values that should be cleared on-transfer.
    await constit.setSpawnProxy(0, owner, {from:user1});
    await constit.setTransferProxy(0, owner, {from:user1});
    await claims.claim(0, "protocol", "claim", "proof", {from:user1});
    // can't do if not owner.
    await assertRevert(constit.transferShip(0, user2, true, {from:user2}));
    // transfer as owner, resetting the ship.
    await constit.transferShip(0, user2, true, {from:user1});
    assert.isTrue(await ships.isOwner(0, user2));
    let [crypt, auth] = await ships.getKeys(0);
    assert.equal(crypt,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await ships.getKeyRevisionNumber(0), 2);
    assert.equal(await ships.getContinuityNumber(0), 1);
    assert.isFalse(await ships.isSpawnProxy(0, user2));
    assert.isFalse(await ships.isTransferProxy(0, user2));
    assert.equal(await claims.getClaimCount(0), 0);
  });

  it('allowing transfer of ownership', async function() {
    // can't do if not owner.
    await assertRevert(constit.setTransferProxy(0, user1, {from:user1}));
    // allow as owner.
    await constit.setTransferProxy(0, user1, {from:user2});
    assert.isTrue(await ships.isTransferProxy(0, user1));
    // transfer as transferrer, but don't reset.
    await constit.transferShip(0, user1, false, {from:user1});
    assert.isTrue(await ships.isOwner(0, user1));
    assert.isTrue(await ships.isTransferProxy(0, user1));
  });

  it('rekeying a ship', async function() {
    // can't do if not owner.
    await assertRevert(constit.configureKeys(0, 9, 8, false, {from:user2}));
    // can't do if ship not active.
    await assertRevert(constit.configureKeys(100, 9, 8, false));
    // rekey as owner.
    await constit.configureKeys(0, 9, 8, false, {from:user1});
    let [crypt, auth] = await ships.getKeys(0);
    assert.equal(crypt,
      '0x9000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x8000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await ships.getKeyRevisionNumber(0), 3);
    await constit.configureKeys(0, 9, 8, true, {from:user1});
    assert.equal(await ships.getContinuityNumber(0), 2);
  });

  it('setting and canceling an escape', async function() {
    // can't if chosen parent not active.
    await assertRevert(constit.escape(257, 1, {from:user1}));
    await constit.configureKeys(1, 8, 9, false, {from:user1});
    // can't if not owner of ship.
    await assertRevert(constit.escape(256, 1, {from:user2}));
    await assertRevert(constit.cancelEscape(256, {from:user2}));
    // galaxies can't escape.
    await assertRevert(constit.escape(0, 1, {from:user1}));
    // set escape as owner.
    await constit.escape(256, 1, {from:user1});
    assert.isTrue(await ships.isRequestingEscapeTo(256, 1));
    await constit.cancelEscape(256, {from:user1});
    assert.isFalse(await ships.isRequestingEscapeTo(256, 1));
    await constit.escape(256, 1, {from:user1});
    await constit.escape(512, 1, {from:user1});
    // try out peer sponsorship.
    await constit.configureKeys(256, 1, 2, false, {from:user1});
    await constit.spawn(65792, owner, {from:user1});
    await constit.spawn(131328, owner, {from:user1});
    assert.isFalse(await constit.canEscapeTo(131328, 65792));
    await constit.configureKeys(65792, 1, 2, false);
    assert.isTrue(await constit.canEscapeTo(131328, 65792));
    await constit.configureKeys(131328, 3, 4, false);
    assert.isFalse(await constit.canEscapeTo(131328, 65792));
  });

  it('adopting or reject an escaping ship', async function() {
    // can't if not owner of parent.
    await assertRevert(constit.adopt(1, 256, {from:user2}));
    await assertRevert(constit.reject(1, 512, {from:user2}));
    // can't if target is not escaping to parent.
    await assertRevert(constit.adopt(1, 258, {from:user1}));
    await assertRevert(constit.reject(1, 258, {from:user1}));
    // adopt as parent owner.
    await constit.adopt(1, 256, {from:user1});
    assert.isFalse(await ships.isRequestingEscapeTo(256, 1));
    assert.equal(await ships.getSponsor(256), 1);
    // reject as parent owner.
    await constit.reject(1, 512, {from:user1});
    assert.isFalse(await ships.isRequestingEscapeTo(512, 1));
    assert.equal(await ships.getSponsor(512), 0);
  });

  it('voting on and updating document poll', async function() {
    // can't if not galaxy owner.
    await assertRevert(constit.startDocumentPoll(0, 10, {from:user2}));
    await assertRevert(constit.castDocumentVote(0, 10, true, {from:user2}));
    await constit.startDocumentPoll(0, 10, {from:user1});
    await constit.castDocumentVote(0, 10, true, {from:user1});
    assert.isTrue(await polls.hasVotedOnDocumentPoll(0, 10));
    await increaseTime(pollTime + 5);
    await constit.updateDocumentPoll(10);
    assert.isTrue(await polls.documentHasAchievedMajority(10));
  });

  it('voting on constitution poll', async function() {
    consti2 = await Constitution.new(constit.address,
                                     ships.address,
                                     polls.address,
                                     ens.address, 'foo', 'sub',
                                     claims.address);
    // can't if not galaxy owner.
    await assertRevert(constit.castConstitutionVote(0, consti2.address, true, {from:user2}));
    await assertRevert(constit.startConstitutionPoll(0, consti2.address, {from:user2}));
    await constit.startConstitutionPoll(0, consti2.address, {from:user1});
    await constit.castConstitutionVote(0, consti2.address, true, {from:user1});
    await constit.castConstitutionVote(1, consti2.address, true, {from:user1});
    assert.equal(await ships.owner(), consti2.address);
    assert.equal(await polls.owner(), consti2.address);
    assert.equal(await ens.owner(namehash('foo.eth')), consti2.address);
    assert.equal(await ens.owner(namehash('sub.foo.eth')), consti2.address);
    assert.equal(await resolver.addr(namehash('sub.foo.eth')),
                  consti2.address);
  });

  it('updating constituton poll', async function() {
    let consti3 = await Constitution.new(consti2.address,
                                         ships.address,
                                         polls.address,
                                         ens.address, 'foo', 'sub',
                                         claims.address);
    // upgraded can only be called by previous constitution
    await assertRevert(consti3.upgraded({from:user2}));
    await consti2.startConstitutionPoll(0, consti3.address, {from:user1});
    await consti2.castConstitutionVote(0, consti3.address, true, {from:user1});
    await increaseTime(pollTime + 5);
    await consti2.updateConstitutionPoll(consti3.address);
    assert.equal(await ships.owner(), consti3.address);
    assert.equal(await polls.owner(), consti3.address);
    assert.equal(await ens.owner(namehash('foo.eth')), consti3.address);
    assert.equal(await ens.owner(namehash('sub.foo.eth')), consti3.address);
    assert.equal(await resolver.addr(namehash('sub.foo.eth')),
                  consti3.address);
  });
});
