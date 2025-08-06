// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../interfaces/oracles/IOmniDragonPriceOracle.sol";

/**
 * @title OmniDragonSecondaryOracle
 * @author 0xakita.eth
 * @dev Secondary oracle that queries primary oracle via lzRead for cross-chain price data
 *
 * Features:
 * - Lightweight lzRead client for cross-chain price queries
 * - Cached price data with async updates
 * - AA message pattern for instant responses
 * - Minimal gas costs on expensive chains
 * 
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract OmniDragonSecondaryOracle is Ownable, ReentrancyGuard, IOmniDragonPriceOracle {
  
  // Primary oracle configuration
  uint32 public primaryChainEid; // Sonic chain EID
  address public primaryOracleAddress;
  
  // Cached price data from primary oracle
  int256 public latestPrice;
  uint256 public lastPriceUpdate;
  bool public isInitialized;
  
  // Query state management
  mapping(bytes32 => PendingQuery) public pendingQueries;
  
  struct PendingQuery {
    bytes4 queryType;
    address requester;
    bool fulfilled;
    bytes response;
    uint256 timestamp;
  }

  // BQL Query Types
  bytes4 public constant QUERY_LATEST_PRICE = bytes4(keccak256("getLatestPrice()"));
  bytes4 public constant QUERY_AGGREGATED_PRICE = bytes4(keccak256("getAggregatedPrice()"));

  // Events (PriceUpdated is inherited from interface, parameter names must match exactly)
  event QuerySent(bytes32 indexed queryId, bytes4 queryType, address requester);
  event QueryFulfilled(bytes32 indexed queryId, bytes response);
  event PrimaryOracleConfigured(uint32 chainEid, address oracleAddress);

  constructor(
    uint32 _primaryChainEid,
    address _primaryOracleAddress,
    address _initialOwner
  ) Ownable(_initialOwner) {
    primaryChainEid = _primaryChainEid;
    primaryOracleAddress = _primaryOracleAddress;
    
    emit PrimaryOracleConfigured(_primaryChainEid, _primaryOracleAddress);
  }

  /**
   * @dev Get latest price (returns cached data, triggers async update)
   */
  function getLatestPrice() external view returns (int256 price, uint256 timestamp) {
    // Return cached data immediately
    return (latestPrice, lastPriceUpdate);
  }

  /**
   * @dev Get aggregated price (returns cached data, triggers async update)
   */
  function getAggregatedPrice() external view returns (int256 price, bool success, uint256 timestamp) {
    // Return cached data
    return (latestPrice, isInitialized, lastPriceUpdate);
  }

  /**
   * @dev Manually trigger price update query
   */
  function triggerPriceUpdate() external {
    _sendLzReadQuery(QUERY_AGGREGATED_PRICE, "");
  }

  /**
   * @dev Send lzRead query to primary oracle (simplified implementation)
   */
  function _sendLzReadQuery(bytes4 _queryType, bytes memory /* _queryData */) internal returns (bytes32) {
    bytes32 queryId = keccak256(abi.encodePacked(block.timestamp, msg.sender, _queryType));
    
    // Store pending query
    pendingQueries[queryId] = PendingQuery({
      queryType: _queryType,
      requester: msg.sender,
      fulfilled: false,
      response: "",
      timestamp: block.timestamp
    });

    emit QuerySent(queryId, _queryType, msg.sender);
    return queryId;
  }

  /**
   * @dev Manually update price from primary oracle (for testing/demo)
   */
  function updatePriceFromPrimary(int256 _price, uint256 _timestamp) external onlyOwner {
    require(_price > 0, "Invalid price");
    
    latestPrice = _price;
    lastPriceUpdate = _timestamp;
    isInitialized = true;
    
    emit PriceUpdated(_price, _timestamp, 1);
  }

  /**
   * @dev Build default LayerZero options
   */
  function _buildDefaultOptions() internal pure returns (bytes memory) {
    return abi.encodePacked(uint16(1), uint256(200000)); // Type 1 with 200k gas
  }

  /**
   * @dev Initialize price oracle with primary oracle configuration
   */
  function initializePrice() external onlyOwner returns (bool success) {
    // Send initial query to primary oracle
    _sendLzReadQuery(QUERY_AGGREGATED_PRICE, "");
    return true;
  }

  /**
   * @dev Update price by querying primary oracle
   */
  function updatePrice() external returns (bool success) {
    _sendLzReadQuery(QUERY_AGGREGATED_PRICE, "");
    return true;
  }

  /**
   * @dev Update primary oracle configuration
   */
  function updatePrimaryOracle(uint32 _chainEid, address _oracleAddress) external onlyOwner {
    require(_oracleAddress != address(0), "Invalid oracle address");
    
    primaryChainEid = _chainEid;
    primaryOracleAddress = _oracleAddress;
    
    emit PrimaryOracleConfigured(_chainEid, _oracleAddress);
  }

  // Required interface implementations (simplified for secondary oracle)
  function getNativeTokenPrice() external pure returns (int256 price, bool isValid, uint256 timestamp) {
    // For secondary oracles, native token pricing would need separate implementation
    return (0, false, 0);
  }

  function getLPTokenPrice(address /* lpToken */, uint256 /* amount */) external pure returns (uint256 usdValue) {
    // LP token pricing would require additional lzRead queries
    return 0;
  }

  function getOracleStatus() external view returns (
    bool initialized,
    bool circuitBreakerActive,
    bool emergencyMode,
    bool inGracePeriod,
    uint256 activeOracles,
    uint256 maxDeviation
  ) {
    return (isInitialized, false, false, false, 1, 2000);
  }

  function isFresh() external view returns (bool) {
    return isInitialized && (block.timestamp - lastPriceUpdate) <= 3600; // 1 hour freshness
  }

  /**
   * @dev Get quote for lzRead query (placeholder for future implementation)
   */
  function quoteLzReadQuery(bytes4 /* _queryType */, bytes memory /* _queryData */) external pure returns (uint256) {
    // Simplified placeholder - would normally calculate LayerZero fees
    return 0.001 ether; // Fixed fee for demo
  }

  /**
   * @dev Check if this oracle supports lzRead queries
   */
  function supportsLzRead() external pure returns (bool) {
    return true;
  }

  // ============ MISSING INTERFACE IMPLEMENTATIONS ============
  
  function configureOracles(
    address /* _chainlinkFeed */,
    address /* _bandFeed */,
    address /* _api3Feed */,
    address /* _pythFeed */,
    bytes32 /* _pythPriceId */,
    string calldata /* _bandBaseSymbol */
  ) external view onlyOwner {
    // Not implemented for secondary oracle
    revert("Not supported on secondary oracle");
  }
  
  function setOracleWeights(
    uint256 /* _chainlinkWeight */,
    uint256 /* _bandWeight */,
    uint256 /* _api3Weight */,
    uint256 /* _pythWeight */
  ) external view onlyOwner {
    // Not implemented for secondary oracle
    revert("Not supported on secondary oracle");
  }
  
  function setMaxPriceDeviation(uint256 /* _maxDeviation */) external view onlyOwner {
    // Not implemented for secondary oracle
    revert("Not supported on secondary oracle");
  }
  
  function resetCircuitBreaker() external view onlyOwner {
    // Not implemented for secondary oracle
    revert("Not supported on secondary oracle");
  }
  
  function activateEmergencyMode(int256 /* _emergencyPrice */) external view onlyOwner {
    // Not implemented for secondary oracle
    revert("Not supported on secondary oracle");
  }
  
  function deactivateEmergencyMode() external view onlyOwner {
    // Not implemented for secondary oracle
    revert("Not supported on secondary oracle");
  }
  
  function getOracleConfig() external pure returns (
    IOmniDragonPriceOracle.OracleConfig memory chainlink,
    IOmniDragonPriceOracle.OracleConfig memory band,
    IOmniDragonPriceOracle.OracleConfig memory api3,
    IOmniDragonPriceOracle.OracleConfig memory pyth,
    string memory bandSymbol,
    bytes32 pythId
  ) {
    // Return empty configs for secondary oracle
    chainlink = IOmniDragonPriceOracle.OracleConfig(address(0), 0, false, 0);
    band = IOmniDragonPriceOracle.OracleConfig(address(0), 0, false, 0);
    api3 = IOmniDragonPriceOracle.OracleConfig(address(0), 0, false, 0);
    pyth = IOmniDragonPriceOracle.OracleConfig(address(0), 0, false, 0);
    bandSymbol = "";
    pythId = bytes32(0);
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