// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PythStructs
 * @dev Pyth Network data structures
 */
library PythStructs {
  struct Price {
    int64 price;
    uint64 conf;
    int32 expo;
    uint256 publishTime;
  }

  struct PriceFeed {
    bytes32 id;
    Price price;
    Price emaPrice;
  }
}