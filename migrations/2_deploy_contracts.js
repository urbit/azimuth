var Azimuth = artifacts.require("Azimuth");
var Polls = artifacts.require("Polls");
var Claims = artifacts.require("Claims");
var Censures = artifacts.require("Censures");
var Ecliptic = artifacts.require("Ecliptic");
var DelegatedSending = artifacts.require("DelegatedSending");
var LinearStarRelease = artifacts.require("LinearStarRelease");
var ConditionalStarRelease = artifacts.require("ConditionalStarRelease");
var Naive = artifacts.require("Naive");

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
  const azimuth = await Azimuth.at('0xbB61Fa683E4B910418E27b00a1438a936234df52');
  const polls = await Polls.at('0xB8473DBd10c98cE9594a53295CF1e9bcA5206BAA');
  const claims = await Claims.at('0xDf2eD5485C28eC61E0Dd4408b4ac350C48bF338d');
  const censures = await Censures.at('0x7312c70c46f9a26609fdc4756a9f15fd4731fbcf');
  const naive = await Naive.at('0x56e37137CdAFc026a732e8E840cD621ed50Bd210')


  //NOTE  for real deployment, use a real ENS registry
  const ecliptic = await Ecliptic.at('0xe1290a3290145e63e6a8ec1ef6616906856d0c8f');

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
