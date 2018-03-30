var Ships = artifacts.require("./Ships.sol");
var Polls = artifacts.require("./Polls.sol");
var Claims = artifacts.require("./Claims.sol");
var Censures = artifacts.require("./Censures.sol");
var Constitution = artifacts.require("./Constitution.sol");
var Pool = artifacts.require("./Pool.sol");

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
  var ships, polls, claims, censures, constitution, pool;
  deployer.then(function() {
  }).then(function() {
    return deployer.deploy(Ships);
  }).then(function() {
    return Ships.deployed();
  }).then(function(instance) {
    ships = instance;
    //TODO test data, maybe in separate migration.
    return deployer.deploy(Polls);
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
    return deployer.deploy(Constitution, 0, ships.address, polls.address);
  }).then(function() {
    return Constitution.deployed();
  }).then(function(instance) {
    constitution = instance;
    ships.transferOwnership(constitution.address);
    polls.transferOwnership(constitution.address);
  }).then(function() {
    return deployer.deploy(Pool, ships.address);
  }).then(function() {
    return Pool.deployed();
  }).then(function(instance) {
    pool = instance;
  });
};
