const Ships = artifacts.require('../contracts/Ships.sol');
const Censures = artifacts.require('../contracts/Censures.sol');

contract('Censures', function([owner, user]) {
  let ships, cens;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    ships = await Ships.new();
    await ships.setOwner(0, owner);
    await ships.setOwner(256, owner);
    await ships.setOwner(65792, owner);
    cens = await Censures.new(ships.address);
  });

  it('censuring', async function() {
    assert.equal(await cens.getCensureCount(0), 0);
    // planets may do nothing.
    try {
      await cens.censure(65792, 131328);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // stars can't censor galaxies.
    try {
      await cens.censure(256, 0);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't self-censor.
    try {
      await cens.censure(256, 256);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // only ship owner can do this.
    try {
      await cens.censure(0, 1, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await cens.censure(0, 1);
    assert.equal(await cens.getCensureCount(0), 1);
    // can't censure twice.
    try {
      await cens.censure(0, 1);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await cens.censure(0, 2);
    await cens.censure(0, 3);
    await cens.censure(0, 4);
    let censures = await cens.getCensures(0);
    assert.equal(censures[0].toNumber(), 1);
    assert.equal(censures[1].toNumber(), 2);
    assert.equal(censures[2].toNumber(), 3);
    assert.equal(censures[3].toNumber(), 4);
  });

  it('forgiving', async function() {
    // can't forgive the uncensured.
    try {
      await cens.forgive(0, 5);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // only ship owner can do this.
    try {
      await cens.forgive(0, 2, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await cens.forgive(0, 2);
    let censures = await cens.getCensures(0);
    assert.equal(censures[0].toNumber(), 1);
    assert.equal(censures[1].toNumber(), 4);
    assert.equal(censures[2].toNumber(), 3);
    assert.equal(await cens.getCensureCount(0), 3);
  });
});
