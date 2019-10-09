var Azimuth = artifacts.require("./Azimuth.sol");
var Polls = artifacts.require("./Polls.sol");
var Claims = artifacts.require("./Claims.sol");
var Censures = artifacts.require("./Censures.sol");
var Ecliptic = artifacts.require("./Ecliptic.sol");
var DelegatedSending = artifacts.require("./DelegatedSending.sol");

const WITH_TEST_STATE = (process.argv[3] === 'with-state');

module.exports = async function(deployer) {
  await deployer;

  // setup contracts
  const azimuth = await deployer.deploy(Azimuth);
  const polls = await deployer.deploy(Polls, 1209600, 604800);
  const claims = await deployer.deploy(Claims, azimuth.address);
  const censures = await deployer.deploy(Censures, azimuth.address);
  //NOTE  for real deployment, use a real ENS registry
  const ecliptic = await deployer.deploy(
    Ecliptic,
    '0x0000000000000000000000000000000000000000',
    azimuth.address, polls.address, claims.address
  );

  // configure contract ownership
  await azimuth.transferOwnership(ecliptic.address);
  await polls.transferOwnership(ecliptic.address);

  // deploy secondary contracts
  const sending = await deployer.deploy(DelegatedSending, azimuth.address);

  // beyond this point: "default" state for qa & testing purposes
  if (!WITH_TEST_STATE) return;

  const own = await ecliptic.owner();
  await ecliptic.createGalaxy(0, own);
  await ecliptic.configureKeys(0, '0x123', '0x456', 1, false);
  await ecliptic.spawn(256, own);
  await ecliptic.configureKeys(256, '0x456', '0x789', 1, false);
  // set transfer proxy to delegated sending, very brittle
  await ecliptic.setSpawnProxy(256, sending.address);
  await ecliptic.spawn(65792, own);
  await ecliptic.spawn(131328, own);
  await ecliptic.spawn(512, own);
  await sending.setPoolSize(256, 65792, 1000);
  await ecliptic.createGalaxy(1, own);
};
