const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const DelegatedSending = artifacts.require('../contracts/DelegatedSending.sol');

contract('Delegated Sending', function([owner, user]) {
  let ships, constit, dese;
  let p1, p2, p3, p4, p5;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    p1 = 65792;
    p2 = 131328;
    p3 = 196864;
    p4 = 262400;
    p5 = 327936;
    //
    ships = await Ships.new();
    polls = await Polls.new(0, 0);
    claims = await Claims.new(ships.address);
    constit = await Constitution.new(0, ships.address, polls.address,
                                     0, '', '', claims.address);
    await ships.transferOwnership(constit.address);
    await polls.transferOwnership(constit.address);
    dese = await DelegatedSending.new(ships.address);
    //
    await constit.createGalaxy(0, owner);
    await constit.configureKeys(0, 0, 0);
    await constit.spawn(256, owner);
    await constit.configureKeys(256, 0, 0);
    await constit.spawn(p1, owner);
    await constit.setSpawnProxy(256, dese.address);
  });

  it('configuring', async function() {
    assert.equal(await dese.limits(256), 0);
    assert.isFalse(await dese.canSend(p1, p2));
    // can only be done by star owner.
    try {
      await dese.configureLimit(256, 1, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await dese.configureLimit(256, 3);
    assert.equal(await dese.limits(256), 3);
    assert.isTrue(await dese.canSend(p1, p2));
  });

  it('sending', async function() {
    // can only be done by ship owner
    try {
      await dese.sendShip(p1, p2, user, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't send to self
    try {
      await dese.sendShip(p1, p2, owner);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // send as regular planet
    await dese.sendShip(p1, p2, user);
    assert.isTrue(await ships.isOwner(p2, user));
    assert.isFalse(await dese.canSend(p1, p2));
    // send as invited planet
    await dese.sendShip(p2, p3, owner, {from:user});
    await dese.sendShip(p3, p4, user, {from:owner});
    // can't send more than the limit
    assert.isFalse(await dese.canSend(p1, p5));
    assert.isFalse(await dese.canSend(p3, p5));
    try {
      await dese.sendShip(p3, p5, user);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
  });

  it('resetting a pool', async function() {
    // can only be done by owner of the target's prefix
    try {
      await dese.resetPool(p3, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await dese.resetPool(p3);
    assert.isTrue(await dese.canSend(p3, p5));
    // shouldn't affect the pool it came from
    assert.isFalse(await dese.canSend(p1, p5));
    await dese.sendShip(p3, p5, user);
  });
});
