// from https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md

pragma solidity 0.4.21;

import "./interfaces/ERC165.sol";

contract ERC165Mapping is ERC165 {
    /// @dev You must not set element 0xffffffff to true
    mapping(bytes4 => bool) internal supportedInterfaces;

    function ERC165MappingImplementation() internal {
        supportedInterfaces[this.supportsInterface.selector] = true;
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return supportedInterfaces[interfaceID];
    }
}
