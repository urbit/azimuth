var Ships = artifacts.require("./Ships.sol");
var Polls = artifacts.require("./Polls.sol");
var Claims = artifacts.require("./Claims.sol");
var Censures = artifacts.require("./Censures.sol");
var Constitution = artifacts.require("./Constitution.sol");

module.exports = async function(deployer) {
  // deployer.deploy([Ships, Polls]);
  // let ships = await Ships.deployed();
  // let polls = await Polls.deployed();
  // deployer.deploy(Constitution, ships.address, polls.address);
  // let constitution = await Constitution.deployed();
  // console.log("Constitution: -- ")
  // console.log(constitution.address)
  // ships.transferOwnership(constitution.address);
  // polls.transferOwnership(constitution.address);

  //TODO the above is more consise and should be the same, but... doesn't work?
  var ships, polls, claims, censures, constitution;
  deployer.then(function() {
  }).then(function() {
    return deployer.deploy(Ships);
  }).then(function() {
    return Ships.deployed();
  }).then(function(instance) {
    ships = instance;
    //TODO test data, maybe in separate migration.
    //
    return deployer.deploy(Polls, 1209600, 604800);
  }).then(function() {
    return Polls.deployed();
  }).then(function(instance) {
    polls = instance;
    return deployer.deploy(Claims, ships.address);
  }).then(function() {
    return Claims.deployed();
  }).then(function(instance) {
    claims = instance;
    return deployer.deploy(Censures, ships.address);
  }).then(function() {
    return Censures.deployed();
  }).then(function(instance) {
    censures = instance;
    //NOTE  for real deployment, we'll want to use a real ENS registry
    //      and node names
    return deployer.deploy(Constitution, 0, ships.address, polls.address,
                                         claims.address);
  }).then(function() {
    return Constitution.deployed();
  }).then(async function(instance) {
    constitution = instance;
    console.log('gonna transfer to constitution now');
    await ships.transferOwnership(constitution.address);
    await polls.transferOwnership(constitution.address);
    //
    var own = await constitution.owner();
    console.log('remember owner ' + own);
    console.log('of constitution ' + constitution.address);
    // await constitution.createGalaxy(0, own);
    // await constitution.configureKeys(0, 123, 456, 1, false);
    // await constitution.spawn(256, own);
    // await constitution.configureKeys(256, 456, 789, 1, false);
    // await constitution.spawn(65792, own);
    // await constitution.spawn(131328, own);
    // await constitution.spawn(512, own);
    // await constitution.createGalaxy(1, own);
    //
  });
};
