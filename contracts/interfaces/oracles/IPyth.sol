// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PythStructs.sol";

/**
 * @title IPyth
 * @dev Interface for Pyth Network price feeds
 */
interface IPyth {
  function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
  
  function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);
  
  function getPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);
}