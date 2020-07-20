// adapted from:
// https://github.com/0xcert/ethereum-erc721/blob/master/test/tokens/NFToken.test.js

const Azimuth = artifacts.require('../contracts/Azimuth.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Ecliptic = artifacts.require('Ecliptic');
const TokenReceiverMock = artifacts.require('NFTokenReceiverTestMock');

// the below hacks around the fact that truffle doesn't play well with overloads

const web3abi = require('web3-eth-abi');
const web3 = Ecliptic.web3;

const overloadedSafeTransferFrom = {
  "constant": false,
  "inputs": [
    {
      "name": "_from",
      "type": "address"
    },
    {
      "name": "_to",
      "type": "address"
    },
    {
      "name": "_tokenId",
      "type": "uint256"
    },
    {
      "name": "_data",
      "type": "bytes"
    }
  ],
  "name": "safeTransferFrom",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function"
};

const assertRevert = require('./helpers/assertRevert');
const seeEvents = require('./helpers/seeEvents');

contract('NFTokenMock', (accounts) => {
  let azimuth, polls, claims, nftoken;
  const id1 = 1;
  const id2 = 2;
  const id3 = 3;
  const id4 = 40;

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
    const nftokenNonExistingInterface = await nftoken.supportsInterface('0xffffffff');
    assert.equal(nftokenInterface, true);
    assert.equal(nftokenNonExistingInterface, false);
  });

  it('returns correct balanceOf after mint', async () => {
    await nftoken.createGalaxy(id1, accounts[0]);
    const count = await nftoken.balanceOf(accounts[0]);
    assert.equal(count.toNumber(), 1);
  });

  it('correctly tells if NFT exists', async () => {
    await nftoken.createGalaxy(id1, accounts[0]);
    assert.isTrue(await nftoken.exists(id1));
    assert.isFalse(await nftoken.exists(id2));
    assert.isFalse(await nftoken.exists(id1+4294967296));
  });

  it('throws when trying to mint 2 NFTs with the same claim', async () => {
    await nftoken.createGalaxy(id2, accounts[0]);
    await assertRevert(nftoken.createGalaxy(id2, accounts[0]));
  });

  it('throws when trying to mint NFT to 0x0 address ', async () => {
    await assertRevert(nftoken.createGalaxy(id3, '0x0000000000000000000000000000000000000000'));
  });

  it('finds the correct amount of NFTs owned by account', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    await nftoken.transferPoint(id2, accounts[1], false, {from:accounts[1]});
    await nftoken.createGalaxy(id3, accounts[1]);
    await nftoken.transferPoint(id3, accounts[1], false, {from:accounts[1]});
    const count = await nftoken.balanceOf(accounts[1]);
    assert.equal(count.toNumber(), 2);
  });

  it('throws when trying to get count of NFTs owned by 0x0 address', async () => {
    await assertRevert(nftoken.balanceOf('0x0000000000000000000000000000000000000000'));
  });

  it('finds the correct owner of NFToken id', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    await nftoken.transferPoint(id2, accounts[1], false, {from:accounts[1]});
    const address = await nftoken.ownerOf(id2);
    assert.equal(address, accounts[1]);
  });

  it('throws when trying to find owner od non-existing NFT id', async () => {
    await assertRevert(nftoken.ownerOf(id4));
  });

  it('correctly approves account', async () => {
    await nftoken.createGalaxy(id2, accounts[0]);
    await nftoken.approve(accounts[1], id2);
    const address = await nftoken.getApproved(id2);
    assert.equal(address, accounts[1]);
  });

  it('correctly cancels approval of account[1]', async () => {
    await nftoken.createGalaxy(id2, accounts[0]);
    await nftoken.approve(accounts[1], id2);
    await nftoken.approve('0x0000000000000000000000000000000000000000',
                          id2);
    const address = await nftoken.getApproved(id2);
    assert.equal(address, 0);
  });

  it('throws when trying to get approval of non-existing NFT id', async () => {
    await assertRevert(nftoken.getApproved(id4));
  });


  it('throws when trying to approve NFT ID which it does not own', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    await nftoken.transferPoint(id2, accounts[1], false, {from:accounts[1]});
    await assertRevert(nftoken.approve(accounts[2], id2, {from: accounts[2]}));
    const address = await nftoken.getApproved(id2);
    assert.equal(address, 0);
  });

  it('throws when trying to approve NFT ID which it already owns', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    await nftoken.transferPoint(id2, accounts[1], false, {from:accounts[1]});
    await assertRevert(nftoken.approve(accounts[1], id2));
    const address = await nftoken.getApproved(id2);
    assert.equal(address, 0);
  });

  it('correctly sets an operator', async () => {
    await nftoken.createGalaxy(id2, accounts[0]);
    await seeEvents(nftoken.setApprovalForAll(accounts[6], true),
      ['ApprovalForAll']);
    const isApprovedForAll = await nftoken.isApprovedForAll(accounts[0], accounts[6]);
    assert.equal(isApprovedForAll, true);
  });

  it('correctly sets then cancels an operator', async () => {
    await nftoken.createGalaxy(id2, accounts[0]);
    await nftoken.setApprovalForAll(accounts[6], true);
    await nftoken.setApprovalForAll(accounts[6], false);

    const isApprovedForAll = await nftoken.isApprovedForAll(accounts[0], accounts[6]);
    assert.equal(isApprovedForAll, false);
  });

  it('throws when trying to set a zero address as operator', async () => {
    await assertRevert(nftoken.setApprovalForAll('0x0000000000000000000000000000000000000000',
                                                 true));
  });

  it('correctly transfers NFT from owner', async () => {
    const sender = accounts[1];
    const recipient = accounts[2];

    await nftoken.createGalaxy(id2, sender);
    await nftoken.transferPoint(id2, sender, false, {from:sender});
    await seeEvents(nftoken.transferFrom(sender, recipient, id2, {from: sender}),
      ['Transfer']);

    const senderBalance = await nftoken.balanceOf(sender);
    const recipientBalance = await nftoken.balanceOf(recipient);
    const ownerOfId2 =  await nftoken.ownerOf(id2);

    assert.equal(senderBalance, 0);
    assert.equal(recipientBalance, 1);
    assert.equal(ownerOfId2, recipient);
  });

  it('correctly transfers NFT from approved address', async () => {
    const sender = accounts[1];
    const recipient = accounts[2];
    const owner = accounts[3];

    await nftoken.createGalaxy(id2, owner);
    await nftoken.transferPoint(id2, owner, false, {from:owner});
    await nftoken.approve(sender, id2, {from: owner});
    await seeEvents(nftoken.transferFrom(owner, recipient, id2, {from: sender}),
      ['Transfer']);

    const ownerBalance = await nftoken.balanceOf(owner);
    const recipientBalance = await nftoken.balanceOf(recipient);
    const ownerOfId2 =  await nftoken.ownerOf(id2);

    assert.equal(ownerBalance, 0);
    assert.equal(recipientBalance, 1);
    assert.equal(ownerOfId2, recipient);
  });

  it('corectly transfers NFT as operator', async () => {
    const sender = accounts[1];
    const recipient = accounts[2];
    const owner = accounts[3];

    await nftoken.createGalaxy(id2, owner);
    await nftoken.transferPoint(id2, owner, false, {from:owner});
    await nftoken.setApprovalForAll(sender, true, {from: owner});
    await seeEvents(nftoken.transferFrom(owner, recipient, id2, {from: sender}),
      ['Transfer']);

    const ownerBalance = await nftoken.balanceOf(owner);
    const recipientBalance = await nftoken.balanceOf(recipient);
    const ownerOfId2 =  await nftoken.ownerOf(id2);

    assert.equal(ownerBalance, 0);
    assert.equal(recipientBalance, 1);
    assert.equal(ownerOfId2, recipient);
  });

  it('throws when trying to transfer NFT as an address that is not owner, approved or operator', async () => {
    const sender = accounts[1];
    const recipient = accounts[2];
    const owner = accounts[3];

    await nftoken.createGalaxy(id2, owner);
    await nftoken.transferPoint(id2, owner, false, {from:owner});
    await assertRevert(nftoken.transferFrom(owner, recipient, id2, {from: sender}));
  });

  it('throws when trying to transfer NFT to a zero address', async () => {
    const owner = accounts[3];

    await nftoken.createGalaxy(id2, owner);
    await nftoken.transferPoint(id2, owner, false, {from:owner});
    await assertRevert(nftoken.transferFrom(owner,
                                            '0x0000000000000000000000000000000000000000',
                                            id2,
                                            {from: owner}));
  });

  it('throws when trying to transfer a invalid NFT', async () => {
    const owner = accounts[3];
    const recipient = accounts[2];

    await nftoken.createGalaxy(id2, owner);
    await nftoken.transferPoint(id2, owner, false, {from:owner});
    await assertRevert(nftoken.transferFrom(owner, recipient, id3, {from: owner}));
  });

  it('correctly safe transfers NFT from owner', async () => {
    const sender = accounts[1];
    const recipient = accounts[2];

    await nftoken.createGalaxy(id2, sender);
    await nftoken.transferPoint(id2, sender, false, {from:sender});
    await seeEvents(nftoken.safeTransferFrom(sender, recipient, id2, {from:
       sender}), ['Transfer']);

    const senderBalance = await nftoken.balanceOf(sender);
    const recipientBalance = await nftoken.balanceOf(recipient);
    const ownerOfId2 =  await nftoken.ownerOf(id2);

    assert.equal(senderBalance, 0);
    assert.equal(recipientBalance, 1);
    assert.equal(ownerOfId2, recipient);
  });

  it('throws when trying to safe transfer NFT from owner to a smart contract', async () => {
    const sender = accounts[1];
    const recipient = nftoken.address;

    await nftoken.createGalaxy(id2, sender);
    await nftoken.transferPoint(id2, sender, false, {from:sender});
    await assertRevert(nftoken.safeTransferFrom(sender, recipient, id2, {from: sender}));
  });

  it('corectly safe transfers NFT from owner to smart contract that can recieve NFTs', async () => {
    const sender = accounts[1];
    const tokenReceiverMock = await TokenReceiverMock.new();
    const recipient = tokenReceiverMock.address;

    await nftoken.createGalaxy(id2, sender);
    await nftoken.transferPoint(id2, sender, false, {from:sender});
    await seeEvents(nftoken.safeTransferFrom(sender, recipient, id2, {from:
       sender}), ['Transfer']);

    const senderBalance = await nftoken.balanceOf(sender);
    const recipientBalance = await nftoken.balanceOf(recipient);
    const ownerOfId2 =  await nftoken.ownerOf(id2);

    assert.equal(senderBalance, 0);
    assert.equal(recipientBalance, 1);
    assert.equal(ownerOfId2, recipient);
  });
});
