pragma solidity 0.4.24;  //  TODO: upgrade!

contract Naive
{
  event Batch();

  function batch(bytes data) external
  {
    emit Batch();
  }
}
