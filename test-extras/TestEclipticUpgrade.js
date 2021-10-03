//  tests upgrade to either the ecliptic included in the repo,
//  or a specified target already on-chain

let nuEclipticAddr = undefined;
const cooked = JSON.parse(process.env.npm_config_argv).cooked;
if (cooked[1] === '--target') {
  nuEclipticAddr = cooked[2];
}

const Azimuth = artifacts.require('Azimuth');
const Ecliptic = artifacts.require('Ecliptic');
const Polls = artifacts.require('Polls');
const Claims = artifacts.require('Claims');

const azimuthAddr = '0x223c067F8CF28ae173EE5CafEa60cA44C335fecB';

contract('Ecliptic', function() {
  let azimuth, ecliptic, polls, nuEcliptic, pollsAddr, senators;

  before('setting up for tests', async function() {
    //  get existing contracts
    //
    azimuth = await Azimuth.at(azimuthAddr);
    const eclipticAddr = await azimuth.owner();
    ecliptic = await Ecliptic.at(eclipticAddr);
    pollsAddr = await ecliptic.polls();
    polls = await Polls.at(pollsAddr);
    claimsAddr = await ecliptic.claims();

    console.log('upgrading from', eclipticAddr);

    //  find addresses to use for voting
    //
    console.log('indexing senators...');
    senators = [];
    for (let i = 0; i < 129; i++) {
      senators.push(azimuth.getOwner(i));
    }
    senators = await Promise.all(senators);

    //  deploy new contracts
    //
    if (nuEclipticAddr) {
      nuEcliptic = await Ecliptic.at(nuEclipticAddr);
    } else {
      nuEcliptic = await Ecliptic.new(eclipticAddr, azimuthAddr, pollsAddr, claimsAddr);
      nuEclipticAddr = nuEcliptic.address;
    }
    console.log('new ecliptic at', nuEclipticAddr);
  });

  it('can be upgraded to', async function() {
    //  start poll, cast majority vote
    //
    console.log('casting votes...');
    const poll = await polls.upgradePolls(nuEclipticAddr);
    const start = poll.start.toNumber();
    const duration = poll.duration.toNumber();
    const cooldown = poll.cooldown.toNumber();
    if (start === 0 || (start + duration + cooldown) < (Date.now() / 1000)) {
      await ecliptic.startUpgradePoll(0, nuEclipticAddr, {
        from: senators[0],
        gasPrice: 0
      });
    }
    for (let i = 0; i < 129; i++) {
      await ecliptic.castUpgradeVote(i, nuEclipticAddr, true, {
        from: senators[i],
        gasPrice: 0
      });
    }
    assert.equal(await azimuth.owner(), nuEclipticAddr);
  });

  it('can still do transfer', async function() {
    assert.isFalse(await azimuth.isOwner(0, senators[1]));  //NOTE  fragile
    await nuEcliptic.transferPoint(0, senators[1], false, {
      from: senators[0],
      gasPrice: 0
    });
    assert.isTrue(await azimuth.isOwner(0, senators[1]));
    senators[0] = senators[1];
  });

  it('can still upgrade', async function () {
    const third = await Ecliptic.new(nuEclipticAddr, azimuthAddr, pollsAddr, await nuEcliptic.claims());
    await nuEcliptic.startUpgradePoll(0, third.address, {
      from: senators[0],
      gasPrice: 0
    });
    console.log('casting votes...');
    for (let i = 0; i < 129; i++) {
      await nuEcliptic.castUpgradeVote(i, third.address, true, {
        from: senators[i],
        gasPrice: 0
      });
    }
    assert.equal(await azimuth.owner(), third.address);
  });

});

