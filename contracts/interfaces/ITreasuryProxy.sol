pragma solidity >=0.4 <0.9;

interface ITreasuryProxy {
  function upgradeTo(address _impl) external returns (bool);

  function freeze() external returns (bool);
}
