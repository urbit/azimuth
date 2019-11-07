var Azimuth = artifacts.require("./Azimuth.sol");
var Polls = artifacts.require("./Polls.sol");
var Claims = artifacts.require("./Claims.sol");
var Censures = artifacts.require("./Censures.sol");
var Ecliptic = artifacts.require("./Ecliptic.sol");
var DelegatedSending = artifacts.require("./DelegatedSending.sol");
var LinearSR = artifacts.require("./LinearStarRelease.sol");
var ConditionalSR = artifacts.require("./ConditionalStarRelease.sol");

const WITH_TEST_STATE = (process.argv[3] === 'with-state');

module.exports = async function(deployer) {
  await deployer;

  const ecliptic = await Ecliptic.at('0x8b9f86a28921d9c705b3113a755fb979e1bd1bce');

  const csr = await deployer.deploy(ConditionalSR, '0x308ab6a6024cf198b57e008d0ac9ad0219886579',
    ['0x0000000000000000000000000000000000000000000000000000000000000000', '0x0000000000000000000000000000000000000000000000000000000000000001', '0x0000000000000000000000000000000000000000000000000000000000000002'],
    [1573385696, 1575977696, 1578656096],
    [1574249696, 1576841696, 1579520096],
    1582198496
  );
  const lsr = await deployer.deploy(LinearSR, '0x308ab6a6024cf198b57e008d0ac9ad0219886579');

  const star = (n) => (197 + (256 * n));

  // 10 stars, one per day
  await lsr.register('0x6DEfFb0caFDB11D175F123F6891AA64F01c24F7d', 0, 10, 1, 86400);
  await ecliptic.setSpawnProxy(star(0), lsr.address);
  for (let i = 1; i <= 10; i++) {
    await lsr.deposit('0x6DEfFb0caFDB11D175F123F6891AA64F01c24F7d', star(i));
  }
  lsr.startReleasing();

  await csr.register('0x6DEfFb0caFDB11D175F123F6891AA64F01c24F7d', [3, 3, 3], 1, 86400);
  await ecliptic.setSpawnProxy(star(0), csr.address);
  for (let i = 11; i <= 19; i++) {
    await csr.deposit('0x6DEfFb0caFDB11D175F123F6891AA64F01c24F7d', star(i));
  }
};
