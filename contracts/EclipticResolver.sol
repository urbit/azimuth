//  ENS resolver for the Ecliptic contract

pragma solidity 0.4.24;

import './interfaces/ResolverInterface.sol';
import './Azimuth.sol';

contract EclipticResolver
{
  Azimuth azimuth;

  constructor(Azimuth _azimuth)
  {
    azimuth = _azimuth;
  }

  function addr(bytes32 node)
    constant
    returns (address)
  {
    //  resolve to the Ecliptic contract
    return azimuth.owner();
  }

  function supportsInterface(bytes4 interfaceID)
    constant
    returns (bool)
  {
    //  supports ERC-137 addr() and ERC-165
    return interfaceID == 0x3b3b57de || interfaceID == 0x01ffc9a7;
  }

  //  ERC-137 resolvers MUST specify a fallback function that throws
  function()
  {
    revert();
  }
}
