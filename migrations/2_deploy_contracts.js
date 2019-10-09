var Azimuth = artifacts.require("./Azimuth.sol");
var Polls = artifacts.require("./Polls.sol");
var Claims = artifacts.require("./Claims.sol");
var Censures = artifacts.require("./Censures.sol");
var Ecliptic = artifacts.require("./Ecliptic.sol");
var DelegatedSending = artifacts.require("./DelegatedSending.sol");

const WITH_TEST_STATE = (process.argv[3] === 'with-state');

module.exports = async function(deployer) {
  // deployer.deploy([Azimuth, Polls]);
  // let azimuth = await Azimuth.deployed();
  // let polls = await Polls.deployed();
  // deployer.deploy(Ecliptic, azimuth.address, polls.address);
  // let ecliptic = await Ecliptic.deployed();
  // console.log("Ecliptic: -- ")
  // console.log(ecliptic.address)
  // azimuth.transferOwnership(ecliptic.address);
  // polls.transferOwnership(ecliptic.address);

  //TODO the above is more consise and should be the same, but... doesn't work?
  var azimuth, polls, claims, censures, ecliptic, sending, own;
  deployer.then(function() {
  }).then(function() {
    return deployer.deploy(Azimuth);
  }).then(function() {
    return Azimuth.deployed();
  }).then(function(instance) {
    azimuth = instance;
    //TODO test data, maybe in separate migration.
    //
    return deployer.deploy(Polls, 1209600, 604800);
  }).then(function() {
    return Polls.deployed();
  }).then(function(instance) {
    polls = instance;
    return deployer.deploy(Claims, azimuth.address);
  }).then(function() {
    return Claims.deployed();
  }).then(function(instance) {
    claims = instance;
    return deployer.deploy(Censures, azimuth.address);
  }).then(function() {
    return Censures.deployed();
  }).then(function(instance) {
    censures = instance;
    //NOTE  for real deployment, we'll want to use a real ENS registry
    //      and node names
    return deployer.deploy(Ecliptic,
                           '0x0000000000000000000000000000000000000000',
                           azimuth.address, polls.address, claims.address);
  }).then(function() {
    return Ecliptic.deployed();
  }).then(async function(instance) {
    ecliptic = instance;
    console.log('gonna transfer to ecliptic now');
    await azimuth.transferOwnership(ecliptic.address);
    await polls.transferOwnership(ecliptic.address);
    //
    own = await ecliptic.owner();
    console.log('remember owner ' + own);
    console.log('of ecliptic ' + ecliptic.address);
  }).then(function() {
    return deployer.deploy(DelegatedSending, azimuth.address);
  }).then(function() {
    return DelegatedSending.deployed();
  }).then(async function(instance) {
    if (!WITH_TEST_STATE) return;
    sending = instance;
    await ecliptic.createGalaxy(0, own);
    console.log(own + ' owns ~zod');
    await ecliptic.configureKeys(0, '0x123', '0x456', 1, false);
    console.log('~zod has keys');
    await ecliptic.spawn(256, own);
    await ecliptic.configureKeys(256, '0x456', '0x789', 1, false);
    // set transfer proxy to delegated sending, very brittle
    await ecliptic.setSpawnProxy(256, sending.address);
    console.log('~marzod transfer proxy set to' + sending.address);
    await ecliptic.spawn(65792, own);
    await ecliptic.spawn(131328, own);
    await ecliptic.spawn(512, own);
    await sending.setPoolSize(256, 65792, 1000);
    await ecliptic.createGalaxy(1, own);
    //
  });
};
