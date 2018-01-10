const Ships = artifacts.require('../contracts/Ships.sol');

contract('Ships', function([owner, user]) {
  let ships;
  const LATENT = 0;
  const LOCKED = 1;
  const LIVING = 2;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    ships = await Ships.new();
  });

  it('getting original parent', async function() {
    // galaxies
    assert.equal(await ships.getOriginalParent(0), 0);
    assert.equal(await ships.getOriginalParent(255), 255);
    // stars
    assert.equal(await ships.getOriginalParent(256), 0);
    assert.equal(await ships.getOriginalParent(65535), 255);
    // planets
    assert.equal(await ships.getOriginalParent(1245952), 768);
  });

  it('getting and setting the ship pilot', async function() {
    assert.equal(await ships.hasPilot(0), false);
    // only owner can do this.
    try {
      await ships.setPilot(0, user, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setPilot(0, user);
    // can't set to same pilot.
    try {
      await ships.setPilot(0, user);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    assert.equal(await ships.hasPilot(0), true);
    assert.equal(await ships.isPilot(0, user), true);
    assert.equal(await ships.isPilot(0, owner), false);
  });

  it('getting owned ships', async function() {
    await ships.setPilot(1, user);
    await ships.setPilot(2, user);
    let owned = await ships.getOwnedShips(user);
    assert.equal(owned[0].toNumber(), 0);
    assert.equal(owned[1].toNumber(), 1);
    assert.equal(owned[2].toNumber(), 2);
    assert.equal(owned.length, 3);
    await ships.setPilot(0, 0);
    owned = await ships.getOwnedShips(user);
    assert.equal(owned[0].toNumber(), 2);
    assert.equal(owned[1].toNumber(), 1);
    assert.equal(owned.length, 2);
  });

  it('setting and testing ship state', async function() {
    // latent
    assert.isTrue(await ships.isState(0, LATENT));
    // locked
    assert.equal(await ships.getLocked(0), 0);
    // only owner can do this.
    try {
      await ships.setLocked(0, 123, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setLocked(0, 123);
    assert.equal(await ships.getLocked(0), 123);
    assert.isTrue(await ships.isState(0, LOCKED));
    // completed
    assert.equal(await ships.getCompleted(0), 0);
    // only owner can do this.
    try {
      await ships.setCompleted(0, 124, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setCompleted(0, 124);
    assert.equal(await ships.getCompleted(0), 124);
    // living
    // only owner can do this.
    try {
      await ships.setLiving(257, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setLiving(257);
    assert.equal(await ships.getParent(257), 1);
    assert.isTrue(await ships.isState(257, LIVING));
    assert.isFalse(await ships.isEscape(257, 0));
    // only owner can do this.
    try {
      await ships.incrementChildren(0, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.incrementChildren(0);
    assert.equal(await ships.getChildren(0), 1);
  });

  it('setting, canceling, and doing escape', async function() {
    // only owner can do this.
    try {
      await ships.setEscape(257, 2, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // only owner can do this.
    try {
      await ships.cancelEscape(257, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setEscape(257, 2);
    assert.isTrue(await ships.isEscape(257, 2));
    await ships.cancelEscape(257);
    assert.isFalse(await ships.isEscape(257, 2));
    // only owner can do this.
    try {
      await ships.doEscape(257, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't do if not escaping.
    try {
      await ships.doEscape(257);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setEscape(257, 2);
    await ships.doEscape(257);
    assert.isFalse(await ships.isEscape(257, 2));
    assert.equal(await ships.getParent(257), 2);
  });

  it('setting key', async function() {
    let [key, rev] = await ships.getKey(0);
    assert.equal(key,
      '0x0000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(rev, 0);
    // only owner can do this.
    try {
      await ships.setKey(0, 10, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setKey(0, 10);
    [key, rev] = await ships.getKey(0);
    assert.equal(key,
      '0xa000000000000000000000000000000000000000000000000000000000000000');
    assert.equal(rev, 1);
  });

  it('setting launcher', async function() {
    assert.isFalse(await ships.isLauncher(0, owner));// only owner can do this.
    try {
      await ships.setLauncher(0, owner, true, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setLauncher(0, owner, true);
    assert.isTrue(await ships.isLauncher(0, owner));
    await ships.setLauncher(0, owner, false);
    assert.isFalse(await ships.isLauncher(0, owner));
  });

  it('setting transferrer', async function() {
    assert.isFalse(await ships.isTransferrer(0, owner));
    // only owner can do this.
    try {
      await ships.setTransferrer(0, owner, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await ships.setTransferrer(0, owner);
    assert.isTrue(await ships.isTransferrer(0, owner));
    await ships.setTransferrer(0, 0);
    assert.isFalse(await ships.isTransferrer(0, owner));
  });
});
