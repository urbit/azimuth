//  SPDX-License-Identifier: MIT
pragma solidity ^0.6.11;

contract NFTokenReceiverTestMock {

  function onERC721Received(
    address _operator,
    address _from,
    uint256 _tokenId,
    bytes _data
  )
    external
    returns(bytes4)
  {
    _operator;
    _from;
    _tokenId;
    _data;
    return 0x150b7a02;
  }

}
