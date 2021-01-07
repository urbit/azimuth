//  contract that uses the Azimuth data contract

pragma solidity 0.4.24;

import './Azimuth.sol';

//  ReadsAzimuth: referring to and testing against the Azimuth
//                data contract
//
//    To avoid needless repetition, this contract provides common
//    checks and operations using the Azimuth contract.
//
contract ReadsAzimuth
{
  //  azimuth: points data storage contract.
  //
  Azimuth public azimuth;

  //  constructor(): set the Azimuth data contract's address
  //
  constructor(Azimuth _azimuth)
    public
  {
    azimuth = _azimuth;
  }

  //  activePointOwner(): require that :msg.sender is the owner of _point,
  //                      and that _point is active
  //
  modifier activePointOwner(uint32 _point)
  {
    require( azimuth.isOwner(_point, msg.sender) &&
             azimuth.isActive(_point) );
    _;
  }

  //  activePointManager(): require that :msg.sender can manage _point,
  //                        and that _point is active
  //
  modifier activePointManager(uint32 _point)
  {
    require( azimuth.canManage(_point, msg.sender) &&
             azimuth.isActive(_point) );
    _;
  }

  //  activePointSpawner(): require that :msg.sender can spawn as _point,
  //                        and that _point is active
  //
  modifier activePointSpawner(uint32 _point)
  {
    require( azimuth.canSpawnAs(_point, msg.sender) &&
             azimuth.isActive(_point) );
    _;
  }

  //  activePointVoter(): require that :msg.sender can vote as _point,
  //                        and that _point is active
  //
  modifier activePointVoter(uint32 _point)
  {
    require( azimuth.canVoteAs(_point, msg.sender) &&
             azimuth.isActive(_point) );
    _;
  }
}
