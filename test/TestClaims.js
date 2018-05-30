const Ships = artifacts.require('../contracts/Ships.sol');
const Claims = artifacts.require('../contracts/Claims.sol');

contract('Claims', function([owner, user]) {
  let ships, claims;

  function assertJump(error) {
    assert.isAbove(error.message.search('revert'), -1, 'Revert must be returned, but got ' + error);
  }

  before('setting up for tests', async function() {
    ships = await Ships.new();
    await ships.setOwner(0, owner);
    claims = await Claims.new(ships.address);
  });

  it('claiming', async function() {
    assert.equal(await claims.getClaimCount(0), 0);
    // only ship owner can do this.
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
    let clam0 = await claims.claims(0, 0);
    assert.equal(clam0[0], "prot1");
    assert.equal(clam0[1], "claim");
    assert.equal(clam0[2], "0x01");
    let clam3 = await claims.claims(0, 3);
    assert.equal(clam3[0], "prot3");
    assert.equal(clam3[1], "claim4");
    assert.equal(clam3[2], "0x04");
  });

  it('disclaiming', async function() {
    // only ship owner can do this.
    try {
      await claims.disclaim(0, "prot2", "claim", {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await claims.disclaim(0, "prot2", "claim");
    assert.equal(await claims.getClaimCount(0), 3);
    let clam3 = await claims.claims(0, 1);
    assert.equal(clam3[0], "prot3");
    assert.equal(clam3[1], "claim4");
    assert.equal(clam3[2], "0x04");
  });

  it('clearing claims', async function() {
    // fill up with claims to ensure we can run the most expensive case
    for (var i = 0; i < 16-3; i++) {
      await claims.claim(0, "some protocol", "some claim "+i, "0x0");
    }
    // can't go over the limit
    try {
      await claims.claim(0, "some protocol", "some claim", "0x0");
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    assert.equal(await claims.getClaimCount(0), 16);
    // only ship owner (and constitution) can clear
    try {
      await claims.clearClaims(0, {from:user});
      assert.fail('should have thrown before');
    } catch(err) {
      assertJump(err);
    }
    await claims.clearClaims(0);
    assert.equal(await claims.getClaimCount(0), 0);
  });
});
