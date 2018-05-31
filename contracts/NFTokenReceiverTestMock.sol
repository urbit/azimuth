pragma solidity ^0.4.21;

contract NFTokenReceiverTestMock {

  function onERC721Received(
    address _from,
    uint256 _tokenId,
    bytes _data
  )
    external
    returns(bytes4)
  {
    _from;
    _tokenId;
    _data;
    return 0xf0b9e5ba;
  }

}
