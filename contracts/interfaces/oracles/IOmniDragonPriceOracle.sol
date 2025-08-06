// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOmniDragonPriceOracle
 * @dev Interface for OmniDragon Price Oracle with multi-source aggregation
 */
interface IOmniDragonPriceOracle {
  // ============ STRUCTS ============

  struct OracleConfig {
    address feedAddress;
    uint256 weight;
    bool isActive;
    uint256 maxStaleness;
  }

  // ============ EVENTS ============

  event PriceUpdated(int256 indexed newPrice, uint256 timestamp, uint256 oracleCount);
  event OracleConfigUpdated(string indexed oracleType, address indexed feedAddress, uint256 weight);
  event CircuitBreakerTriggered(string reason, int256 oldPrice, int256 newPrice, uint256 deviation);
  event CircuitBreakerReset(address indexed admin);
  event PriceInitialized(int256 initialPrice, uint256 timestamp);
  event MaxDeviationUpdated(uint256 oldDeviation, uint256 newDeviation);
  event EmergencyModeActivated(int256 emergencyPrice);
  event EmergencyModeDeactivated();

  // ============ MAIN FUNCTIONS ============

  function getLatestPrice() external view returns (int256 price, uint256 timestamp);

  function getAggregatedPrice() external view returns (int256 price, bool success, uint256 timestamp);

  /**
   * @notice Get the native token price (e.g., SONIC/USD, ETH/USD)
   * @return price The price of native token in USD (8 decimals)
   * @return isValid Whether the price is valid
   * @return timestamp The timestamp of the price
   */
  function getNativeTokenPrice() external view returns (int256 price, bool isValid, uint256 timestamp);

  function initializePrice() external returns (bool success);

  function updatePrice() external returns (bool success);

  // ============ ADMIN FUNCTIONS ============

  function configureOracles(
    address _chainlinkFeed,
    address _bandFeed,
    address _api3Feed,
    address _pythFeed,
    bytes32 _pythPriceId,
    string calldata _bandBaseSymbol
  ) external;

  function setOracleWeights(
    uint256 _chainlinkWeight,
    uint256 _bandWeight,
    uint256 _api3Weight,
    uint256 _pythWeight
  ) external;

  function setMaxPriceDeviation(uint256 _maxDeviation) external;

  function resetCircuitBreaker() external;

  function activateEmergencyMode(int256 _emergencyPrice) external;

  function deactivateEmergencyMode() external;

  // ============ VIEW FUNCTIONS ============

  function getOracleConfig()
    external
    view
    returns (
      OracleConfig memory chainlink,
      OracleConfig memory band,
      OracleConfig memory api3,
      OracleConfig memory pyth,
      string memory bandSymbol,
      bytes32 pythId
    );

  function isFresh() external view returns (bool);

  function getOracleStatus()
    external
    view
    returns (
      bool initialized,
      bool circuitBreakerActive,
      bool emergencyMode,
      bool inGracePeriod,
      uint256 activeOracles,
      uint256 maxDeviation
    );

  /**
   * @notice Get USD value of LP tokens
   * @param lpToken LP token address
   * @param amount Amount of LP tokens (18 decimals)
   * @return usdValue USD value scaled by 1e6
   */
  function getLPTokenPrice(address lpToken, uint256 amount) external view returns (uint256 usdValue);
}