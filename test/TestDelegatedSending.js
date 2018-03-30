const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Constitution = artifacts.require('../contracts/Constitution.sol');
const DelegatedSending = artifacts.require('../contracts/DelegatedSending.sol');

contract('Delegated Sending', function([owner, user]) {
  let ships, constit, dese;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    ships = await Ships.new();
    polls = await Polls.new();
    constit = await Constitution.new(0, ships.address, polls.address);
    await ships.transferOwnership(constit.address);
    await polls.transferOwnership(constit.address);
    dese = await DelegatedSending.new(ships.address);
    //
    await constit.createGalaxy(0, owner);
    await constit.configureKeys(0, 0, 0);
    await constit.spawn(256, owner);
    await constit.configureKeys(256, 0, 0);
    await constit.spawn(65792, owner);
    await constit.setSpawnProxy(256, dese.address);
  });

  it('configuring', async function() {
    assert.equal(await dese.limits(256), 0);
    assert.isFalse(await dese.canSend(65792, 131328));
    // can only be done by star owner.
    try {
      await dese.configureLimit(256, 1, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await dese.configureLimit(256, 1);
    assert.equal(await dese.limits(256), 1);
    assert.isTrue(await dese.canSend(65792, 131328));
  });

  it('sending', async function() {
    // can only be done by ship owner
    try {
      await dese.sendShip(65792, 131328, user, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // can't send to self
    try {
      await dese.sendShip(65792, 131328, owner);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await dese.sendShip(65792, 131328, user);
    assert.isTrue(await ships.isOwner(131328, user));
    assert.isFalse(await dese.canSend(65792, 131328));
    // can't send more than the limit.
    assert.isFalse(await dese.canSend(65792, 196864));
    try {
      await dese.sendShip(65792, 196864, user);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
  });
});
