// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title OmniDragonRegistryProxy (minimal)
 * @dev Minimal, non-upgrade-admin proxy that delegates all calls to an implementation.
 *      Constructor stores the implementation address; no admin functions.
 */
contract OmniDragonRegistryProxy {
  address public immutable implementation;

  constructor(address _implementation) {
    require(_implementation != address(0), "impl=0");
    implementation = _implementation;
  }

  receive() external payable {}

  fallback() external payable {
    address impl = implementation;
    assembly {
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}


