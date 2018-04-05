const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');

contract('Constitution', function([owner, user1, user2]) {
  let ships, polls, constit, consti2, pollTime;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  // because setTimeout doesn't work.
  function busywait(s) {
    var start = Date.now();
    var ms = s * 1000;
    while (true) {
      if ((Date.now() - start) > ms) break;
    }
  }

  before('setting up for tests', async function() {
    pollTime = 3;
    ships = await Ships.new();
    polls = await Polls.new(pollTime, pollTime);
    claims = await Claims.new(ships.address);
    constit = await Constitution.new(0, ships.address, polls.address,
                                     claims.address);
    await ships.transferOwnership(constit.address);
    await polls.transferOwnership(constit.address);
  });

  it('creating galaxies', async function() {
    // create.
    await constit.createGalaxy(0, user1);
    assert.isTrue(await ships.isActive(0));
    assert.isTrue(await ships.isOwner(0, user1));
    // can't create twice.
    try {
      await constit.createGalaxy(0, owner);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // non-owner can't create.
    try {
      await constit.createGalaxy(1, user1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // prep for next tests.
    await constit.createGalaxy(1, user1);
    await constit.createGalaxy(2, user1);
    assert.equal(await polls.totalVoters(), 3);
  });

  it('spawning ships', async function() {
    // can't spawn if not parent owner.
    try {
      await constit.spawn(256, user1, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't spawn if parent not live.
    try {
      await constit.spawn(256, user1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.configureKeys(0, 1, 2, {from:user1});
    // spawn child.
    await constit.spawn(256, user1, {from:user1});
    assert.isTrue(await ships.isOwner(256, user1));
    assert.isTrue(await ships.isActive(256));
    // can't launch same ship twice.
    try {
      await constit.spawn(256, user1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
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
    try {
      await constit.setSpawnProxy(0, user2, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // set up for working launch.
    await constit.setSpawnProxy(0, user2, {from:user1});
    assert.isTrue(await ships.isSpawnProxy(0, user2));
    // launch as launcher, then test revoking of rights.
    await constit.spawn(768, user1, {from:user2});
    await constit.setSpawnProxy(0, 0, {from:user1});
    assert.isFalse(await ships.isSpawnProxy(0, user2));
  });

  it('transfering ownership', async function() {
    // set values that should be cleared on-transfer.
    await constit.setSpawnProxy(0, owner, {from:user1});
    await constit.setTransferProxy(0, owner, {from:user1});
    await claims.claim(0, "protocol", "claim", "proof", {from:user1});
    // can't do if not owner.
    try {
      await constit.transferShip(0, user2, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // transfer as owner, resetting the ship.
    await constit.transferShip(0, user2, true, {from:user1});
    assert.isTrue(await ships.isOwner(0, user2));
    let [crypt, auth] = await ships.getKeys(0);
    assert.equal(crypt,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await ships.getKeyRevisionNumber(0), 2);
    assert.isFalse(await ships.isSpawnProxy(0, user2));
    assert.isFalse(await ships.isTransferProxy(0, user2));
    assert.equal(await claims.getClaimCount(0), 0);
  });

  it('allowing transfer of ownership', async function() {
    // can't do if not owner.
    try {
      await constit.setTransferProxy(0, user1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
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
    try {
      await constit.configureKeys(0, 9, 8, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't do if ship not active.
    try {
      await constit.configureKeys(100, 9, 8);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // rekey as owner.
    await constit.configureKeys(0, 9, 8, {from:user1});
    let [crypt, auth] = await ships.getKeys(0);
    assert.equal(crypt,
      '0x9000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x8000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await ships.getKeyRevisionNumber(0), 3);
  });

  it('setting and canceling an escape', async function() {
    // can't if chosen parent not active.
    try {
      await constit.escape(257, 1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.configureKeys(1, 8, 9, {from:user1});
    // can't if not owner of ship.
    try {
      await constit.escape(256, 1, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    try {
      await constit.cancelEscape(256, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // galaxies can't escape.
    try {
      await constit.escape(0, 1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // set escape as owner.
    await constit.escape(256, 1, {from:user1});
    assert.isTrue(await ships.isEscape(256, 1));
    await constit.cancelEscape(256, {from:user1});
    assert.isFalse(await ships.isEscape(256, 1));
    await constit.escape(256, 1, {from:user1});
    await constit.escape(512, 1, {from:user1});
    // try out peer sponsorship.
    await constit.configureKeys(256, 1, 2, {from:user1});
    await constit.spawn(65792, owner, {from:user1});
    await constit.spawn(131328, owner, {from:user1});
    assert.isFalse(await constit.canEscapeTo(131328, 65792));
    await constit.configureKeys(65792, 1, 2);
    assert.isTrue(await constit.canEscapeTo(131328, 65792));
    await constit.configureKeys(131328, 3, 4);
    assert.isFalse(await constit.canEscapeTo(131328, 65792));
  });

  it('adopting or reject an escaping ship', async function() {
    // can't if not owner of parent.
    try {
      await constit.adopt(1, 256, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    try {
      await constit.reject(1, 512, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't if target is not escaping to parent.
    try {
      await constit.adopt(1, 258, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    try {
      await constit.reject(1, 258, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // adopt as parent owner.
    await constit.adopt(1, 256, {from:user1});
    assert.isFalse(await ships.isEscape(256, 1));
    assert.equal(await ships.getSponsor(256), 1);
    // reject as parent owner.
    await constit.reject(1, 512, {from:user1});
    assert.isFalse(await ships.isEscape(512, 1));
    assert.equal(await ships.getSponsor(512), 0);
  });

  it('voting on and updating abstract poll', async function() {
    // can't if not galaxy owner.
    try {
      await constit.startAbstractPoll(0, 10, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    try {
      await constit.castAbstractVote(0, 10, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.startAbstractPoll(0, 10, {from:user1});
    await constit.castAbstractVote(0, 10, true, {from:user1});
    assert.isTrue(await polls.hasVotedOnAbstractPoll(0, 10));
    busywait(pollTime * 1.3); // make timing less tight
    await constit.updateAbstractPoll(10);
    assert.isTrue(await polls.abstractMajorityMap(10));
  });

  it('voting on concrete poll', async function() {
    consti2 = await Constitution.new(constit.address,
                                     ships.address,
                                     polls.address,
                                     claims.address);
    // can't if not galaxy owner.
    try {
      await constit.castConcreteVote(0, consti2.address, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    try {
      await constit.startConcretePoll(0, consti2.address, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await constit.startConcretePoll(0, consti2.address, {from:user1});
    await constit.castConcreteVote(0, consti2.address, true, {from:user1});
    await constit.castConcreteVote(1, consti2.address, true, {from:user1});
    assert.equal(await ships.owner(), consti2.address);
    assert.equal(await polls.owner(), consti2.address);
  });

  it('updating concrete poll', async function() {
    let consti3 = await Constitution.new(consti2.address,
                                         ships.address,
                                         polls.address,
                                         claims.address);
    await consti2.startConcretePoll(0, consti3.address, {from:user1});
    await consti2.castConcreteVote(0, consti3.address, true, {from:user1});
    busywait(pollTime * 1.3); // make timing less tight
    await consti2.updateConcretePoll(consti3.address);
    assert.equal(await ships.owner(), consti3.address);
    assert.equal(await polls.owner(), consti3.address);
  });
});
