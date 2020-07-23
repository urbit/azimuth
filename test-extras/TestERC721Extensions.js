// adapted from:
// https://github.com/0xcert/ethereum-erc721/blob/master/test/tokens/NFTokenMetadataEnumerable.test.js

const Azimuth = artifacts.require('Azimuth');
const Polls = artifacts.require('Polls');
const Claims = artifacts.require('Claims');
const Ecliptic = artifacts.require('Ecliptic');

const assertRevert = require('../test/helpers/assertRevert');

contract('NFTokenMetadataMock', (accounts) => {
  let azimuth, polls, claims, nftoken;
  const id1 = 1;
  const id2 = 2;
  const id3 = 3;
  const id4 = 4294967297;

  beforeEach(async () => {
    azimuth = await Azimuth.new();
    polls = await Polls.new(432000, 432000);
    claims = await Claims.new(azimuth.address);
    nftoken = await Ecliptic.new('0x0000000000000000000000000000000000000000',
                                 azimuth.address,
                                 polls.address,
                                 claims.address);
    azimuth.transferOwnership(nftoken.address);
    polls.transferOwnership(nftoken.address);
  });

  it('correctly checks all the supported interfaces', async () => {
    const nftokenInterface = await nftoken.supportsInterface('0x80ac58cd');
    const nftokenMetadataInterface = await nftoken.supportsInterface('0x5b5e139f');
    assert.equal(nftokenInterface, true);
    assert.equal(nftokenMetadataInterface, true);
  });

  it('returns the correct issuer name', async () => {
    const name = await nftoken.name();
    assert.equal(name, 'Azimuth Points');
  });

  it('returns the correct issuer symbol', async () => {
    const symbol = await nftoken.symbol();
    assert.equal(symbol, 'AZP');
  });

  it('returns the correct NFT id 2 url', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    const tokenURI = await nftoken.tokenURI(id2);
    assert.equal(tokenURI, 'https://azimuth.network/erc721/0000000002.json');
  });

  it('throws when trying to get uri of none existant NFT id', async () => {
    await assertRevert(nftoken.tokenURI(id4));
  });
});
