var Ships = artifacts.require("./Ships.sol");
var Votes = artifacts.require("./Votes.sol");
var Spark = artifacts.require("./Spark.sol");
var Constitution = artifacts.require("./Constitution.sol");

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
  var ships, votes, spark, constitution;
  deployer.then(function() {
  }).then(function() {
    return deployer.deploy([Ships, Votes, Spark]);
  }).then(function() {
    return Ships.deployed();
  }).then(function(instance) {
    ships = instance;
    return Votes.deployed();
  }).then(function(instance) {
    votes = instance;
    return Spark.deployed();
  }).then(function(instance) {
    spark = instance;
    return deployer.deploy(Constitution, ships.address, votes.address, spark.address);
  }).then(function() {
    return Constitution.deployed();
  }).then(function(instance) {
    constitution = instance;
    console.log("new owner is:");
    console.log(constitution.address);
    ships.transferOwnership(constitution.address);
    votes.transferOwnership(constitution.address);
    spark.transferOwnership(constitution.address);
  });
};
