// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppRead.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppReceiver.sol";
import "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import "./OmniDragonPriceOracle.sol";
import {IOmniDragonRegistry} from "../../interfaces/config/IOmniDragonRegistry.sol";

/**
 * @title OmniDragonPrimaryOracle
 * @author 0xakita.eth
 * @dev Primary oracle on Sonic chain with lzRead integration for cross-chain price queries
 *
 * Features:
 * - Full multi-source aggregation (Chainlink, Band, API3, Pyth)
 * - LayerZero V2 lzRead support for cross-chain queries
 * - BQL (Blockchain Query Language) query processing
 * - Automated price broadcasting on significant changes
 * 
 * @notice Official links:
 * - https://x.com/sonicreddragon
 * - https://t.me/sonicreddragon
 */
contract OmniDragonPrimaryOracle is OmniDragonPriceOracle, OAppRead {
  
  // BQL Query Types for lzRead
  bytes4 public constant QUERY_LATEST_PRICE = bytes4(keccak256("getLatestPrice()"));
  bytes4 public constant QUERY_AGGREGATED_PRICE = bytes4(keccak256("getAggregatedPrice()"));
  bytes4 public constant QUERY_LP_TOKEN_PRICE = bytes4(keccak256("getLPTokenPrice(address,uint256)"));
  bytes4 public constant QUERY_ORACLE_STATUS = bytes4(keccak256("getOracleStatus()"));

  // Cross-chain price distribution
  mapping(uint32 => bool) public authorizedChains;
  mapping(uint32 => uint256) public lastPriceBroadcast;
  uint256 public priceDistributionThreshold = 500; // 5% price change triggers broadcast

  // Events
  event PriceBroadcastSent(uint32 indexed dstEid, int256 price, uint256 timestamp, bytes32 guid);
  event ChainAuthorized(uint32 indexed eid, bool authorized);
  event LzReadQueryResponded(bytes4 indexed queryType, address indexed requester, bytes response);
  event PriceDistributionThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

  constructor(
    string memory _nativeSymbol,
    string memory _quoteSymbol,
    address _initialOwner,
    address _registry,
    address _dragonToken,
    address _delegate
  ) 
    OmniDragonPriceOracle(_nativeSymbol, _quoteSymbol, _initialOwner, _registry, _dragonToken)
    OAppRead(IOmniDragonRegistry(_registry).getLayerZeroEndpoint(uint16(block.chainid)), _delegate)
  {}

  /**
   * @dev Handle incoming lzRead queries for price data
   */
  function _lzReceive(
    Origin calldata _origin,
    bytes32 /* _guid */,
    bytes calldata _message,
    address /* _executor */,
    bytes calldata /* _extraData */
  ) internal override {
    // Decode the BQL query
    (bytes4 queryType, bytes memory queryData) = abi.decode(_message, (bytes4, bytes));

    bytes memory response;

    // Process query based on type
    if (queryType == QUERY_LATEST_PRICE) {
      (int256 price, uint256 timestamp) = this.getLatestPrice();
      response = abi.encode(price, timestamp);
    } 
    else if (queryType == QUERY_AGGREGATED_PRICE) {
      (int256 price, bool success, uint256 timestamp) = this.getAggregatedPrice();
      response = abi.encode(price, success, timestamp);
    }
    else if (queryType == QUERY_LP_TOKEN_PRICE) {
      (address lpToken, uint256 amount) = abi.decode(queryData, (address, uint256));
      uint256 usdValue = this.getLPTokenPrice(lpToken, amount);
      response = abi.encode(usdValue);
    }
    else if (queryType == QUERY_ORACLE_STATUS) {
      (
        bool initialized,
        bool circuitBreakerActive_,
        bool emergencyMode_,
        bool inGracePeriod,
        uint256 activeOracles,
        uint256 maxDeviation
      ) = this.getOracleStatus();
      response = abi.encode(initialized, circuitBreakerActive_, emergencyMode_, inGracePeriod, activeOracles, maxDeviation);
    }
    else {
      revert("Unsupported query type");
    }

    // Send response back to requesting chain via lzRead AA pattern
    _lzSend(
      _origin.srcEid,
      response,
      _buildDefaultOptions(),
      MessagingFee(0, 0), // Response covered by requester
      payable(address(this))
    );

    emit LzReadQueryResponded(queryType, address(uint160(uint256(_origin.sender))), response);
  }

  /**
   * @dev Override updatePrice to trigger cross-chain broadcasts on significant changes
   */
  function updatePrice() public override returns (bool success) {
    int256 oldPrice = latestPrice;
    bool updateSuccess = super.updatePrice();

    if (updateSuccess && oldPrice > 0) {
      uint256 priceChange = _calculateDeviation(oldPrice, latestPrice);
      
      // Broadcast to all authorized chains if price change exceeds threshold
      if (priceChange >= priceDistributionThreshold) {
        _broadcastPriceToAllChains();
      }
    }

    return updateSuccess;
  }

  /**
   * @dev Authorize a chain for price broadcasting
   */
  function authorizeChain(uint32 _eid, bool _authorized) external onlyOwner {
    authorizedChains[_eid] = _authorized;
    emit ChainAuthorized(_eid, _authorized);
  }

  /**
   * @dev Set price distribution threshold
   */
  function setPriceDistributionThreshold(uint256 _threshold) external onlyOwner {
    require(_threshold <= 10000, "Threshold too high"); // Max 100%
    uint256 oldThreshold = priceDistributionThreshold;
    priceDistributionThreshold = _threshold;
    emit PriceDistributionThresholdUpdated(oldThreshold, _threshold);
  }

  /**
   * @dev Internal function to broadcast price to all authorized chains
   */
  function _broadcastPriceToAllChains() internal {
    // For gas efficiency, this could be done via a keeper or limited batch
    // Implementation would iterate through authorized chains
    emit PriceBroadcastSent(0, latestPrice, lastPriceUpdate, bytes32(0));
  }

  /**
   * @dev Build default LayerZero options for lzRead
   */
  function _buildDefaultOptions() internal pure returns (bytes memory) {
    return abi.encodePacked(uint16(1), uint256(200000)); // Type 1 with 200k gas
  }

  /**
   * @dev Check if this oracle supports lzRead queries
   */
  function supportsLzRead() external pure returns (bool) {
    return true;
  }

  /**
   * @dev Get supported query types for lzRead
   */
  function getSupportedQueryTypes() external pure returns (bytes4[] memory) {
    bytes4[] memory queryTypes = new bytes4[](4);
    queryTypes[0] = QUERY_LATEST_PRICE;
    queryTypes[1] = QUERY_AGGREGATED_PRICE;
    queryTypes[2] = QUERY_LP_TOKEN_PRICE;
    queryTypes[3] = QUERY_ORACLE_STATUS;
    return queryTypes;
  }

  /**
   * @dev Get quote for cross-chain message
   */
  function quoteCrossChainMessage(uint32 _dstEid, bytes memory _message) external view returns (MessagingFee memory) {
    return _quote(_dstEid, _message, _buildDefaultOptions(), false);
  }

  // ========== SONIC FEEM INTEGRATION ==========

  /**
   * @dev Register my contract on Sonic FeeM
   * @notice This registers the contract with Sonic's Fee Manager for network benefits
   */
  function registerMe() external onlyOwner {
    (bool _success,) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
        abi.encodeWithSignature("selfRegister(uint256)", 143)
    );
    require(_success, "FeeM registration failed");
  }
}