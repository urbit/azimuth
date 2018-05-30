// adapted from:
// https://github.com/0xcert/ethereum-erc721/blob/master/test/tokens/NFTokenMetadataEnumerable.test.js

const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('Constitution');

async function assertRevert(promise) {
  try {
    await promise;
    assert.fail('Expected revert not received');
  } catch (error) {
    var revertFound = error.message.search('revert') >= 0;
    revertFound = revertFound || error.message.search('fail') >= 0;
    assert(revertFound, `Expected "revert", got ${error} instead`);
  }
};

contract('NFTokenMetadataEnumerableMock', (accounts) => {
  let ships, polls, claims, nftoken;
  const id1 = 1;
  const id2 = 2;
  const id3 = 3;
  const id4 = 40;

  beforeEach(async () => {
    ships = await Ships.new();
    polls = await Polls.new(0, 0);
    claims = await Claims.new(ships.address);
    nftoken = await Constitution.new(0, ships.address, polls.address, 0, '', '', claims.address);
    ships.transferOwnership(nftoken.address);
    polls.transferOwnership(nftoken.address);
  });

  it('correctly checks all the supported interfaces', async () => {
    const nftokenInterface = await nftoken.supportsInterface('0x80ac58cd');
    const nftokenMetadataInterface = await nftoken.supportsInterface('0x5b5e139f');
    const nftokenEnumerableInterface = await nftoken.supportsInterface('0x780e9d63');
    assert.equal(nftokenInterface, true);
    assert.equal(nftokenMetadataInterface, true);
    assert.equal(nftokenEnumerableInterface, true);
  });

  it('returns the correct issuer name', async () => {
    const name = await nftoken.name();
    assert.equal(name, 'Urbit Ship');
  });

  it('returns the correct issuer symbol', async () => {
    const symbol = await nftoken.symbol();
    assert.equal(symbol, 'URS');
  });

  it('returns the correct NFT id 2 url', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    const tokenURI = await nftoken.tokenURI(id2);
    assert.equal(tokenURI, 'https://eth.urbit.org/erc721/0000000002.json');
  });

  it('throws when trying to get uri of none existant NFT id', async () => {
    await assertRevert(nftoken.tokenURI(id4));
  });

  it('returns the correct total supply', async () => {
    const totalSupply0 = await nftoken.totalSupply();
    assert.equal(totalSupply0, 4294967296);
  });

  it('returns the correct token by index', async () => {
    await nftoken.createGalaxy(id1, accounts[1]);
    await nftoken.createGalaxy(id2, accounts[1]);
    await nftoken.createGalaxy(id3, accounts[2]);

    const tokenId = await nftoken.tokenByIndex(1);
    assert.equal(tokenId.toNumber(), 1);
  });

  it('throws when trying to get token by unexistant index', async () => {
    await nftoken.createGalaxy(id1, accounts[1]);
    await assertRevert(nftoken.tokenByIndex(1));
  });

  it('returns the correct token of owner by index', async () => {
    await nftoken.createGalaxy(id1, accounts[1]);
    await nftoken.createGalaxy(id2, accounts[1]);
    await nftoken.createGalaxy(id3, accounts[2]);

    const tokenId = await nftoken.tokenOfOwnerByIndex(accounts[1], 1);
    assert.equal(tokenId.toNumber(), id2);
  });

  it('throws when trying to get token of owner by unexistant index', async () => {
    await nftoken.createGalaxy(id1, accounts[1]);
    await nftoken.createGalaxy(id3, accounts[2]);

    await assertRevert(nftoken.tokenOfOwnerByIndex(accounts[1], 1));
  });
});
