const Ships = artifacts.require('../contracts/Ships.sol');
const Claims = artifacts.require('../contracts/Claims.sol');

const assertRevert = require('./helpers/assertRevert');

contract('Claims', function([owner, user]) {
  let ships, claims;

  before('setting up for tests', async function() {
    ships = await Ships.new();
    await ships.setOwner(0, owner);
    claims = await Claims.new(ships.address);
  });

  it('claiming', async function() {
    assert.equal(await claims.getClaimCount(0), 0);
    // only ship owner can do this.
    await assertRevert(claims.addClaim(0, "prot1", "claim", "0x0", {from:user}));
    await claims.addClaim(0, "prot1", "claim", "0x0");
    assert.equal(await claims.getClaimCount(0), 1);
    // can update the proof.
    await claims.addClaim(0, "prot1", "claim", "0x01");
    await claims.addClaim(0, "prot2", "claim", "0x02");
    await claims.addClaim(0, "prot3", "claim", "0x03");
    await claims.addClaim(0, "prot3", "claim4", "0x04");
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
    await assertRevert(claims.removeClaim(0, "prot2", "claim", {from:user}));
    await claims.removeClaim(0, "prot2", "claim");
    assert.equal(await claims.getClaimCount(0), 3);
    let clam3 = await claims.claims(0, 1);
    assert.equal(clam3[0], "prot3");
    assert.equal(clam3[1], "claim4");
    assert.equal(clam3[2], "0x04");
  });

  it('clearing claims', async function() {
    // fill up with claims to ensure we can run the most expensive case
    for (var i = 0; i < 16-3; i++) {
      await claims.addClaim(0, "some protocol", "some claim "+i, "0x0");
    }
    // can't go over the limit
    await assertRevert(claims.addClaim(0, "some protocol", "some claim", "0x0"));
    assert.equal(await claims.getClaimCount(0), 16);
    // only ship owner (and constitution) can clear
    await assertRevert(claims.clearClaims(0, {from:user}));
    await claims.clearClaims(0);
    assert.equal(await claims.getClaimCount(0), 0);
    // make sure things still work as expected.
    await claims.addClaim(0, "prot1", "claim", "0x01");
    await claims.addClaim(0, "prot2", "claim", "0x02");
    assert.equal(await claims.getClaimCount(0), 2);
    let clam0 = await claims.claims(0, 0);
    assert.equal(clam0[0], "prot1");
    assert.equal(clam0[1], "claim");
    assert.equal(clam0[2], "0x01");
  });
});
