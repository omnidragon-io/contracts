// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
  MessagingFee,
  MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title IChainlinkVRFIntegratorV2_5
 * @dev Interface for Chainlink VRF v2.5 integrator with LayerZero cross-chain capabilities
 */
interface IChainlinkVRFIntegratorV2_5 {
  // ============ STRUCTS ============

  struct VRFConfig {
    uint64 subscriptionId;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords;
    bool enabled;
  }

  struct CrossChainVRFRequest {
    uint32 dstEid;
    address requester;
    uint256 nonce;
    uint256 timestamp;
    bool fulfilled;
  }

  // ============ EVENTS ============

  event VRFRequested(uint256 indexed requestId, address indexed requester, uint32 indexed dstEid, uint256 nonce);

  event VRFFulfilled(uint256 indexed requestId, uint256[] randomWords, address indexed requester);

  event CrossChainVRFRequested(
    uint32 indexed dstEid,
    address indexed requester,
    uint256 indexed nonce,
    uint256 requestId
  );

  event CrossChainVRFFulfilled(
    uint32 indexed srcEid,
    address indexed requester,
    uint256 indexed nonce,
    uint256[] randomWords
  );

  event VRFConfigUpdated(
    uint64 subscriptionId,
    bytes32 keyHash,
    uint32 callbackGasLimit,
    uint16 requestConfirmations,
    uint32 numWords,
    bool enabled
  );

  event AuthorizedCallerUpdated(address indexed caller, bool indexed authorized);

  // ============ VRF FUNCTIONS (Professional API) ============

  function quoteFee() external view returns (MessagingFee memory fee);

  function quoteFeeWithGas(uint32 gasLimit) external view returns (MessagingFee memory fee);

  function requestRandomWords(uint32 dstEid) external returns (MessagingReceipt memory receipt, uint64 requestId);

  function requestRandomWordsPayable(uint32 dstEid) external payable returns (MessagingReceipt memory receipt, uint64 requestId);

  // ============ ADMIN FUNCTIONS ============

  function updateVRFConfig(
    uint64 subscriptionId,
    bytes32 keyHash,
    uint32 callbackGasLimit,
    uint16 requestConfirmations,
    uint32 numWords,
    bool enabled
  ) external;

  function setAuthorizedCaller(address caller, bool authorized) external;

  function withdrawLink(uint256 amount) external;

  function withdrawNative(uint256 amount) external;

  // ============ VIEW FUNCTIONS ============

  function getVRFConfig() external view returns (VRFConfig memory);

  function isAuthorizedCaller(address caller) external view returns (bool);

  function getCrossChainRequest(uint256 nonce) external view returns (CrossChainVRFRequest memory);

  function getRequestStatus(uint256 requestId) external view returns (bool fulfilled, uint256[] memory randomWords);

  // Legacy quote signature removed in favor of quoteFee/quoteFeeWithGas

  // ============ LAYERZERO INTEGRATION ============

  function lzReceive(uint32 srcEid, bytes32 sender, uint64 nonce, bytes calldata payload) external;
}