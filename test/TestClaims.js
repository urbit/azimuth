const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Claims = artifacts.require('../contracts/Claims.sol');

const assertRevert = require('./helpers/assertRevert');

contract('Claims', function([owner, user]) {
  let azimuth, claims;

  before('setting up for tests', async function() {
    azimuth = await Azimuth.new();
    await azimuth.setOwner(0, owner);
    await azimuth.activatePoint(0);
    claims = await Claims.new(azimuth.address);
  });

  it('claiming', async function() {
    // only point owner can do this.
    await assertRevert(claims.addClaim(0, "prot1", "claim", "0x0", {from:user}));
    await claims.addClaim(0, "prot1", "claim", "0x0");
    // can update the proof.
    await claims.addClaim(0, "prot1", "claim", "0x01");
    await claims.addClaim(0, "prot2", "claim", "0x02");
    await claims.addClaim(0, "prot3", "claim", "0x03");
    await claims.addClaim(0, "prot3", "claim4", "0x04");
    let clam0 = await claims.claims(0, 0);
    assert.equal(clam0[0], "prot1");
    assert.equal(clam0[1], "claim");
    assert.equal(clam0[2], "0x01");
    let clam3 = await claims.claims(0, 3);
    assert.equal(clam3[0], "prot3");
    assert.equal(clam3[1], "claim4");
    assert.equal(clam3[2], "0x04");
    let clam4 = await claims.claims(0, 4);
    assert.equal(clam4[0], "");
    assert.equal(clam4[1], "");
    assert.equal(clam4[2], null);
  });

  it('removing claim', async function() {
    // only point owner can do this.
    await assertRevert(claims.removeClaim(0, "prot2", "claim", {from:user}));
    // can't remove non-existent claim
    await assertRevert(claims.removeClaim(0, "prot2", "!!!"));
    await claims.removeClaim(0, "prot2", "claim");
    let clam1 = await claims.claims(0, 1);
    assert.equal(clam1[0], "");
    assert.equal(clam1[1], "");
    assert.equal(clam1[2], null);
    await claims.addClaim(0, "prot2", "claim2", "0x22");
    clam1 = await claims.claims(0, 1);
    assert.equal(clam1[0], "prot2");
    assert.equal(clam1[1], "claim2");
    assert.equal(clam1[2], "0x22");
  });

  it('clearing claims', async function() {
    // fill up with claims to ensure we can run the most expensive case
    for (var i = 0; i < 16-4; i++) {
      await claims.addClaim(0, "some protocol", "some claim "+i, "0x0");
    }
    // can't go over the limit
    await assertRevert(claims.addClaim(0, "some protocol", "some claim", "0x0"));
    let clam16 = await claims.claims(0, 15);
    assert.equal(clam16[0], "some protocol");
    assert.equal(clam16[1], "some claim "+(15-4));
    assert.equal(clam16[2], "0x00");
    // only point owner (and ecliptic) can clear
    await assertRevert(claims.clearClaims(0, {from:user}));
    await claims.clearClaims(0);
    for (var i = 0; i < 16; i++) {
      let clam = await claims.claims(0, i);
      assert.equal(clam[0], "");
      assert.equal(clam[1], "");
      assert.equal(clam[2], null);
    }
    // make sure things still work as expected.
    await claims.addClaim(0, "prot1", "claim", "0x01");
    await claims.addClaim(0, "prot2", "claim", "0x02");
    let clam0 = await claims.claims(0, 1);
    assert.equal(clam0[0], "prot2");
    assert.equal(clam0[1], "claim");
    assert.equal(clam0[2], "0x02");
  });
});
