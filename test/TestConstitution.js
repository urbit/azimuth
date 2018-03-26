const Ships = artifacts.require('../contracts/Ships.sol');
const Votes = artifacts.require('../contracts/Votes.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Censures = artifacts.require('../contracts/Censures.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');

contract('Constitution', function([owner, user1, user2]) {
  let ships, votes, constit;
  const LATENT = 0;
  const LOCKED = 1;
  const LIVING = 2;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  // because setTimeout doesn't work.
  function busywait(ms) {
    var start = Date.now();
    while (true) {
      if ((Date.now() - start) > ms) break;
    }
  }

  before('setting up for tests', async function() {
    ships = await Ships.new();
    votes = await Votes.new();
    constit = await Constitution.new(ships.address, votes.address);
    await ships.transferOwnership(constit.address);
    await votes.transferOwnership(constit.address);
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
  });

  it('spawning ships', async function() {
    // can't start if not parent owner.
    try {
      await constit.spawn(256, user1, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't start if parent not living.
    try {
      await constit.spawn(259, user1, {from:user1});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
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
    // can't do if not owner.
    try {
      await constit.transferShip(0, user2, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // transfer as owner.
    await constit.transferShip(0, user2, true, {from:user1});
    assert.isTrue(await ships.isOwner(0, user2));
    let [crypt, auth] = await ships.getKeys(0);
    assert.equal(crypt,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(auth,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(await ships.getKeyRevisionNumber(0), 1);
    assert.isFalse(await ships.isSpawnProxy(0, user2));
    assert.isFalse(await ships.isTransferProxy(0, user2));
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
    assert.equal(await ships.getKeyRevisionNumber(0), 2);
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

  it('casting an abstract vote', async function() {
    // can't if not galaxy owner.
    try {
      await constit.castAbstractVote(0, 10, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // TODO can't if galaxy not keyed?
    await constit.castAbstractVote(0, 10, true, {from:user1});
    assert.equal(await votes.abstractVoteCounts(10), 1);
    await constit.castAbstractVote(0, 10, false, {from:user1});
    assert.equal(await votes.abstractVoteCounts(10), 0);
  });

  it('casting a concrete vote', async function() {
    let consti2 = await Constitution.new(ships.address, votes.address);
    // can't if not galaxy owner.
    try {
      await constit.castConcreteVote(0, consti2.address, true, {from:user2});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    //TODO can't if galaxy not keyed?
    await constit.castConcreteVote(0, consti2.address, true, {from:user1});
    assert.equal(
        await votes.concreteVoteCounts(constit.address, consti2.address),
        1);
    await constit.castConcreteVote(0, consti2.address, false, {from:user1});
    assert.equal(
        await votes.concreteVoteCounts(constit.address, consti2.address),
        0);
    await constit.castConcreteVote(0, consti2.address, true, {from:user1});
    await constit.castConcreteVote(1, consti2.address, true, {from:user1});
    assert.equal(await ships.owner(), consti2.address);
    assert.equal(await votes.owner(), consti2.address);
  });
});
