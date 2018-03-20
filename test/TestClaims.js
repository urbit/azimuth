const Claims = artifacts.require('../contracts/Claims.sol');

contract('Claims', function([owner, user]) {
  let claims;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    claims = await Claims.new();
  });

  it('claiming', async function() {
    assert.equal(await claims.getClaimCount(0), 0);
    try {
      await claims.getClaimAtIndex(0, 0);
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    // only owner can do this.
    try {
      await claims.claim(0, "prot1", "claim", "0x0", {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await claims.claim(0, "prot1", "claim", "0x0");
    assert.equal(await claims.getClaimCount(0), 1);
    // can update the proof.
    await claims.claim(0, "prot1", "claim", "0x01");
    await claims.claim(0, "prot2", "claim", "0x02");
    await claims.claim(0, "prot3", "claim", "0x03");
    await claims.claim(0, "prot3", "claim4", "0x04");
    assert.equal(await claims.getClaimCount(0), 4);
    let clam0 = await claims.getClaimAtIndex(0, 0);
    assert.equal(clam0[0], "prot1");
    assert.equal(clam0[1], "claim");
    assert.equal(clam0[2], "0x01");
    let clam3 = await claims.getClaimAtIndex(0, 3);
    assert.equal(clam3[0], "prot3");
    assert.equal(clam3[1], "claim4");
    assert.equal(clam3[2], "0x04");
  });

  it('disclaiming', async function() {
    // only owner can do this.
    try {
      await claims.disclaim(0, "prot2", "claim", {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await claims.disclaim(0, "prot2", "claim");
    assert.equal(await claims.getClaimCount(0), 3);
    let clam3 = await claims.getClaimAtIndex(0, 1);
    assert.equal(clam3[0], "prot3");
    assert.equal(clam3[1], "claim4");
    assert.equal(clam3[2], "0x04");
  });
});
