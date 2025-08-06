// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IApi3ReaderProxy
 * @dev Interface for API3 dAPI reader proxy
 */
interface IApi3ReaderProxy {
  function read() external view returns (int224 value, uint32 timestamp);
}