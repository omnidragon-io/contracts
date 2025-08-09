// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
import {IOmniDragonRegistry} from "../../interfaces/config/IOmniDragonRegistry.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppRead.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppReceiver.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";

/**
 * @title OmniDragonSecondaryOracle
 * @author 0xakita.eth
 * @dev OApp that retrieves aggregated price from the Primary Oracle via LayerZero lzRead.
 *      Stores the latest received value and exposes view accessors for frontends/contracts.
 */
contract OmniDragonSecondaryOracle is OAppRead {
  // Query selector used by PrimaryOracle to route read requests
  bytes4 public constant QUERY_AGGREGATED_PRICE = bytes4(keccak256("getAggregatedPrice()"));

  // Primary oracle location (on Sonic)
  address public primaryOracle;
  uint32 public primaryChainEid; // Sonic EID = 30332

  // Cached price data
  int256 public latestPrice; // 18 decimals
  uint256 public lastPriceUpdate; // timestamp
  bool public lastReadSuccess;

  // Config
  uint256 public defaultGasLimit = 200000; // for lzRead callback on primary

  // Events
  event PrimaryConfigured(address primaryOracle, uint32 primaryEid);
  event AggregatedPriceRequested(bytes32 guid, uint32 dstEid, uint256 gasLimit, uint256 feePaid);
  event AggregatedPriceUpdated(int256 price, bool success, uint256 timestamp);
  event DefaultGasLimitUpdated(uint256 oldGas, uint256 newGas);

constructor(
    address _registry,
    address _delegate,
    address _primaryOracle,
    uint32 _primaryEid
  ) OAppRead(IOmniDragonRegistry(_registry).getLayerZeroEndpoint(uint16(block.chainid)), _delegate) Ownable(msg.sender) {
    primaryOracle = _primaryOracle;
    primaryChainEid = _primaryEid;
    emit PrimaryConfigured(_primaryOracle, _primaryEid);
  }

  /**
   * @notice Admin: set the primary oracle location
   */
  function setPrimaryOracle(address _primaryOracle, uint32 _primaryEid) external {
    require(_primaryOracle != address(0), "invalid primary");
    primaryOracle = _primaryOracle;
    primaryChainEid = _primaryEid;
    emit PrimaryConfigured(_primaryOracle, _primaryEid);
  }

  /**
   * @notice Admin: adjust the default gas for primary's callback execution
   */
  function setDefaultGasLimit(uint256 gasLimit) external {
    require(gasLimit >= 100000 && gasLimit <= 1000000, "bad gas");
    uint256 old = defaultGasLimit;
    defaultGasLimit = gasLimit;
    emit DefaultGasLimitUpdated(old, gasLimit);
  }

  /**
   * @notice Request aggregated price from the primary oracle via lzRead
   * @dev msg.value should cover the messaging fee; any excess is refunded by the endpoint
   * @param gasLimit Gas budget for primary's _lzReceive execution
   * @return guid LayerZero message GUID
   */
  function requestAggregatedPrice(uint256 gasLimit) external payable returns (bytes32 guid) {
    require(primaryOracle != address(0) && primaryChainEid != 0, "primary not set");

    // Encode query (type + empty payload)
    bytes memory query = abi.encode(QUERY_AGGREGATED_PRICE, bytes(""));
    // Options: Type 1 with provided gas
    bytes memory options = abi.encodePacked(uint16(1), gasLimit == 0 ? defaultGasLimit : gasLimit);

    MessagingReceipt memory receipt = _lzSend(
      primaryChainEid,
      abi.encode(query),
      options,
      MessagingFee(msg.value, 0),
      payable(msg.sender)
    );

    emit AggregatedPriceRequested(receipt.guid, primaryChainEid, gasLimit == 0 ? defaultGasLimit : gasLimit, msg.value);
    return receipt.guid;
  }

  /**
   * @dev Handle response from Primary. Expects (price, success, timestamp) encoding.
   */
  function _lzReceive(
    Origin calldata _origin,
    bytes32 /*_guid*/,
    bytes calldata _message,
    address /*_executor*/,
    bytes calldata /*_extraData*/
  ) internal override {
    // Ensure the response comes from the configured primary chain
    require(_origin.srcEid == primaryChainEid, "bad src eid");

    // Primary encodes response directly as ABI-encoded tuple for the specific query
    // For aggregated price, it encodes: (int256 price, bool success, uint256 timestamp)
    (int256 price, bool success, uint256 timestamp) = abi.decode(_message, (int256, bool, uint256));

    latestPrice = price;
    lastReadSuccess = success;
    lastPriceUpdate = timestamp;

    emit AggregatedPriceUpdated(price, success, timestamp);
  }

  /**
   * @notice Get last received aggregated price
   * @return price 18-decimal price, success flag, last update timestamp
   */
  function getAggregatedPrice() external view returns (int256 price, bool success, uint256 timestamp) {
    return (latestPrice, lastReadSuccess, lastPriceUpdate);
  }
}


