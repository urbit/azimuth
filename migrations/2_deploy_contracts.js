var Ships = artifacts.require("./Ships.sol");
var Votes = artifacts.require("./Votes.sol");
var Claims = artifacts.require("./Claims.sol");
var Censures = artifacts.require("./Censures.sol");
var Constitution = artifacts.require("./Constitution.sol");
var Pool = artifacts.require("./Pool.sol");

module.exports = async function(deployer) {
  // deployer.deploy([Ships, Votes]);
  // let ships = await Ships.deployed();
  // let votes = await Votes.deployed();
  // deployer.deploy(Constitution, ships.address, votes.address);
  // let constitution = await Constitution.deployed();
  // console.log("Constitution: -- ")
  // console.log(constitution.address)
  // ships.transferOwnership(constitution.address);
  // votes.transferOwnership(constitution.address);

  //TODO the above is more consise and should be the same, but... doesn't work?
  var ships, votes, claims, censures, constitution, pool;
  deployer.then(function() {
  }).then(function() {
    return deployer.deploy(Ships);
  }).then(function() {
    return Ships.deployed();
  }).then(function(instance) {
    ships = instance;
    return deployer.deploy(Votes);
  }).then(function() {
    return Votes.deployed();
  }).then(function(instance) {
    votes = instance;
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
    return deployer.deploy(Constitution, ships.address, votes.address);
  }).then(function() {
    return Constitution.deployed();
  }).then(function(instance) {
    constitution = instance;
    console.log("new owner is:");
    console.log(constitution.address);
    ships.transferOwnership(constitution.address);
    votes.transferOwnership(constitution.address);
  }).then(function() {
    return deployer.deploy(Pool, ships.address);
  }).then(function() {
    return Pool.deployed();
  }).then(function(instance) {
    pool = instance;
    console.log("new pool address:");
    console.log(pool.address);
  });
};
