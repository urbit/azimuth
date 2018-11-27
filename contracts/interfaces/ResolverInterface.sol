// https://github.com/ethereum/ens

pragma solidity ^0.4.18;

contract ResolverInterface {
    function addr(bytes32 node) public view returns (address);
    function supportsInterface(bytes4 interfaceID) public pure returns (bool);
}
