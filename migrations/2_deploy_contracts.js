var Azimuth = artifacts.require("./Azimuth.sol");
var Polls = artifacts.require("./Polls.sol");
var Claims = artifacts.require("./Claims.sol");
var Censures = artifacts.require("./Censures.sol");
var Ecliptic = artifacts.require("./Ecliptic.sol");
var DelegatedSending = artifacts.require("./DelegatedSending.sol");
var LinearStarRelease = artifacts.require("./LinearStarRelease.sol");
var ConditionalStarRelease = artifacts.require("./ConditionalStarRelease.sol");

const WITH_TEST_STATE = process.argv[3] === "with-state";

const windup = 20;
const rateUnit = 50;
const deadlineStep = 100;
const condit2 = web3.utils.fromAscii("1234");
const escapeHatchTime = deadlineStep * 100;

async function getChainTime() {
  const block = await web3.eth.getBlock("latest");

  return block.timestamp;
}

module.exports = async function(deployer, network, accounts) {
  await deployer;

  // setup contracts
  const azimuth = await deployer.deploy(Azimuth);
  const polls = await deployer.deploy(Polls, 1209600, 604800);
  const claims = await deployer.deploy(Claims, azimuth.address);
  const censures = await deployer.deploy(Censures, azimuth.address);


  //NOTE  for real deployment, use a real ENS registry
  const ecliptic = await deployer.deploy(
    Ecliptic,
    "0x0000000000000000000000000000000000000000",
    azimuth.address,
    polls.address,
    claims.address
  );

  // configure contract ownership
  await azimuth.transferOwnership(ecliptic.address);
  await polls.transferOwnership(ecliptic.address);

  // deploy secondary contracts
  const sending = await deployer.deploy(DelegatedSending, azimuth.address);

  const deadline1 = web3.utils.toDecimal(await getChainTime()) + 10;
  const deadline2 = deadline1 + deadlineStep;
  const escapeHatchDate =
    web3.utils.toDecimal(await getChainTime()) + escapeHatchTime;

  const conditionalSR = await deployer.deploy(
    ConditionalStarRelease,
    azimuth.address,
    ["0x0", condit2],
    [0, 0],
    [deadline1, deadline2],
    escapeHatchDate
  );
  const linearSR = await deployer.deploy(LinearStarRelease, azimuth.address);
  linearSR.startReleasing();


  // beyond this point: "default" state for qa & testing purposes
  if (!WITH_TEST_STATE) return;

  const own = await ecliptic.owner();
  const releaseUser = accounts[1];


  await ecliptic.createGalaxy(0, own);
  await ecliptic.configureKeys(0, "0x123", "0x456", 1, false);
  await ecliptic.spawn(256, own);
  await ecliptic.configureKeys(256, "0x456", "0x789", 1, false);
  // set transfer proxy to delegated sending, very brittle
  await ecliptic.setSpawnProxy(256, sending.address);
  await ecliptic.spawn(65792, own);
  await ecliptic.spawn(131328, own);
  await ecliptic.spawn(512, own);
  await sending.setPoolSize(256, 65792, 1000);

  //  Linear Star Release
  await ecliptic.createGalaxy(1, own);

  await ecliptic.configureKeys(1, "0xABC", "0xDEF", 1, false);

  await ecliptic.setSpawnProxy(1, linearSR.address);

  await linearSR.register(releaseUser, windup, 8, 2, rateUnit);

  // Conditional Star Release
  await ecliptic.createGalaxy(2, own);
  await ecliptic.configureKeys(2, "0x321", "0x654", 1, false);

  await ecliptic.setSpawnProxy(2, conditionalSR.address);

  await conditionalSR.register(releaseUser, [4, 4], 1, rateUnit);

  for (let i = 1; i < 9; i++) {
    const offset = 256 * i;
    await linearSR.deposit(releaseUser, offset + 1);
    await conditionalSR.deposit(releaseUser, offset + 2);
  }
};
