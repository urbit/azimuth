// adapted from:
// https://github.com/0xcert/ethereum-erc721/blob/master/test/tokens/NFToken.test.js

const Ships = artifacts.require('../contracts/Ships.sol');
const Polls = artifacts.require('../contracts/Polls.sol');
const Claims = artifacts.require('../contracts/Claims.sol');
const Constitution = artifacts.require('Constitution');
const TokenReceiverMock = artifacts.require('NFTokenReceiverTestMock');

// the below hacks around the fact that truffle doesn't play well with overloads

const web3abi = require('web3-eth-abi');
const web3 = Constitution.web3;

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
    }
  ],
  "name": "safeTransferFrom",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function"
};

const assertRevert = require('./helpers/assertRevert');

contract('NFTokenMock', (accounts) => {
  let ships, polls, claims, nftoken;
  const id1 = 1;
  const id2 = 2;
  const id3 = 3;
  const id4 = 40;

  beforeEach(async () => {
    ships = await Ships.new();
    polls = await Polls.new(432000, 432000);
    claims = await Claims.new(ships.address);
    nftoken = await Constitution.new(0, ships.address, polls.address, 0, '', '', claims.address);
    ships.transferOwnership(nftoken.address);
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

  it('throws when trying to mint 2 NFTs with the same claim', async () => {
    await nftoken.createGalaxy(id2, accounts[0]);
    await assertRevert(nftoken.createGalaxy(id2, accounts[0]));
  });

  it('throws when trying to mint NFT to 0x0 address ', async () => {
    await assertRevert(nftoken.createGalaxy(id3, '0'));
  });

  it('finds the correct amount of NFTs owned by account', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    await nftoken.createGalaxy(id3, accounts[1]);
    const count = await nftoken.balanceOf(accounts[1]);
    assert.equal(count.toNumber(), 2);
  });

  it('throws when trying to get count of NFTs owned by 0x0 address', async () => {
    await assertRevert(nftoken.balanceOf('0'));
  });

  it('finds the correct owner of NFToken id', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
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
    await nftoken.approve(0, id2);
    const address = await nftoken.getApproved(id2);
    assert.equal(address, 0);
  });

  it('throws when trying to get approval of non-existing NFT id', async () => {
    await assertRevert(nftoken.getApproved(id4));
  });


  it('throws when trying to approve NFT ID which it does not own', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    await assertRevert(nftoken.approve(accounts[2], id2, {from: accounts[2]}));
    const address = await nftoken.getApproved(id2);
    assert.equal(address, 0);
  });

  it('throws when trying to approve NFT ID which it already owns', async () => {
    await nftoken.createGalaxy(id2, accounts[1]);
    await assertRevert(nftoken.approve(accounts[1], id2));
    const address = await nftoken.getApproved(id2);
    assert.equal(address, 0);
  });

  it('correctly sets an operator', async () => {
    await nftoken.createGalaxy(id2, accounts[0]);
    const { logs } = await nftoken.setApprovalForAll(accounts[6], true);
    const approvalForAllEvent = logs.find(e => e.event === 'ApprovalForAll');
    assert.notEqual(approvalForAllEvent, undefined);
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
    await assertRevert(nftoken.setApprovalForAll(0, true));
  });

  it('correctly transfers NFT from owner', async () => {
    const sender = accounts[1];
    const recipient = accounts[2];

    await nftoken.createGalaxy(id2, sender);
    const { logs } = await nftoken.transferFrom(sender, recipient, id2, {from: sender});
    const transferEvent = logs.find(e => e.event === 'Transfer');
    assert.notEqual(transferEvent, undefined);

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
    await nftoken.approve(sender, id2, {from: owner});
    const { logs } = await nftoken.transferFrom(owner, recipient, id2, {from: sender});
    const transferEvent = logs.find(e => e.event === 'Transfer');
    assert.notEqual(transferEvent, undefined);

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
    await nftoken.setApprovalForAll(sender, true, {from: owner});
    const { logs } = await nftoken.transferFrom(owner, recipient, id2, {from: sender});
    const transferEvent = logs.find(e => e.event === 'Transfer');
    assert.notEqual(transferEvent, undefined);

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
    await assertRevert(nftoken.transferFrom(owner, recipient, id2, {from: sender}));
  });

  it('throws when trying to transfer NFT to a zero address', async () => {
    const owner = accounts[3];

    await nftoken.createGalaxy(id2, owner);
    await assertRevert(nftoken.transferFrom(owner, 0, id2, {from: owner}));
  });

  it('throws when trying to transfer a invalid NFT', async () => {
    const owner = accounts[3];
    const recipient = accounts[2];

    await nftoken.createGalaxy(id2, owner);
    await assertRevert(nftoken.transferFrom(owner, recipient, id3, {from: owner}));
  });

  it('correctly safe transfers NFT from owner', async () => {
    const sender = accounts[1];
    const recipient = accounts[2];

    await nftoken.createGalaxy(id2, sender);
    const { logs } = await nftoken.safeTransferFrom(sender, recipient, id2, '', {from: sender});
    const transferEvent = logs.find(e => e.event === 'Transfer');
    assert.notEqual(transferEvent, undefined);

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
    const safeTransferFromData = web3abi.encodeFunctionCall(
      overloadedSafeTransferFrom, [sender, recipient, id2]);
    try {
      web3.eth.call({
        from: sender,
        to: nftoken.address,
        data: safeTransferFromData,
        value: 0
      });
      assert.fail(missed);
    } catch(err) {
      assert.isAbove(err.message.search('revert'), -1, 'Revert must be returned, but got ' + err);
    }
  });

  it('corectly safe transfers NFT from owner to smart contract that can recieve NFTs', async () => {
    const sender = accounts[1];
    const tokenReceiverMock = await TokenReceiverMock.new();
    const recipient = tokenReceiverMock.address;

    await nftoken.createGalaxy(id2, sender);
    const { logs } = await nftoken.safeTransferFrom(sender, recipient, id2, '', {from: sender});
    const transferEvent = logs.find(e => e.event === 'Transfer');
    assert.notEqual(transferEvent, undefined);

    const senderBalance = await nftoken.balanceOf(sender);
    const recipientBalance = await nftoken.balanceOf(recipient);
    const ownerOfId2 =  await nftoken.ownerOf(id2);

    assert.equal(senderBalance, 0);
    assert.equal(recipientBalance, 1);
    assert.equal(ownerOfId2, recipient);
  });
});
