// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IChainlinkAggregator {
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
  function decimals() external view returns (uint8);
}

interface IStdReference {
  struct ReferenceData {
    uint256 rate;
    uint256 lastUpdatedBase;
    uint256 lastUpdatedQuote;
  }
  function getReferenceData(string memory _base, string memory _quote) external view returns (ReferenceData memory);
}

import "../../interfaces/oracles/IApi3ReaderProxy.sol";
import "../../interfaces/oracles/IPyth.sol";
import "../../interfaces/oracles/PythStructs.sol";
import "../../interfaces/tokens/IUniswapV2Pair.sol";
import "../../interfaces/config/IOmniDragonRegistry.sol";

/**
 * @title OmniDragonPriceOracle
 * @author 0xakita.eth
 * @dev Robust price oracle that aggregates prices from multiple oracle sources
 *
 * This oracle supports:
 * - Chainlink price feeds
 * - Band Protocol feeds
 * - API3 dAPI feeds
 * - Pyth Network feeds
 *
 * Features:
 * - Weighted average price calculation
 * - Configurable oracle weights
 * - Smart circuit breaker protection with initialization grace period
 * - Price freshness validation
 * - Network-specific configuration
 * - Adaptive deviation thresholds
 * - Emergency price override capabilities
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract OmniDragonPriceOracle is Ownable, Pausable, ReentrancyGuard {
  // ═══════════════════════════════════════════════════════════════════════════════════════
  // STRUCTS AND ENUMS
  // ═══════════════════════════════════════════════════════════════════════════════════════

  struct OracleConfig {
    address feedAddress;
    uint256 weight;
    bool isActive;
    uint256 maxStaleness;
  }

  struct PriceData {
    int256 price;
    uint256 timestamp;
    bool isValid;
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════════════════

  // Basic configuration
  string public nativeSymbol;
  string public quoteSymbol;
  uint8 public constant DECIMALS = 18;

  // Current price state
  int256 public latestPrice;
  uint256 public lastPriceUpdate;
  bool public isInitialized;

  // Oracle configurations
  OracleConfig public chainlinkConfig;
  OracleConfig public bandConfig;
  OracleConfig public api3Config;
  OracleConfig public pythConfig;

  // Network-specific settings
  string public bandProtocolBaseSymbol;
  bytes32 public pythPriceId;

  // Native token price feeds
  mapping(uint256 => address) public nativeTokenPriceFeeds; // chainId => Chainlink feed

  // Safety settings - now configurable
  uint256 public maxPriceDeviation = 2000; // 20% max deviation (configurable)
  uint256 public initializationGracePeriod = 86400; // 24 hours grace period for initialization
  uint256 public constant DEFAULT_MAX_STALENESS = 3600; // 1 hour
  bool public circuitBreakerActive;
  uint256 public deploymentTime;

  // Emergency controls
  bool public emergencyMode;
  int256 public emergencyPrice;

  // LP Token pricing configuration
  IOmniDragonRegistry public registry;
  address public dragonToken;

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // EVENTS
  // ═══════════════════════════════════════════════════════════════════════════════════════

  event PriceUpdated(int256 indexed newPrice, uint256 timestamp, uint256 oracleCount);
  event OracleConfigUpdated(string indexed oracleType, address indexed feedAddress, uint256 weight);
  event CircuitBreakerTriggered(string reason, int256 oldPrice, int256 newPrice, uint256 deviation);
  event CircuitBreakerReset(address indexed admin);
  event PriceInitialized(int256 initialPrice, uint256 timestamp);
  event MaxDeviationUpdated(uint256 oldDeviation, uint256 newDeviation);
  event EmergencyModeActivated(int256 emergencyPrice);
  event EmergencyModeDeactivated();

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CUSTOM ERRORS
  // ═══════════════════════════════════════════════════════════════════════════════════════

  error InvalidWeights();
  error CircuitBreakerActive();
  error PriceDataStale();
  error NoValidOracleData();
  error InvalidPriceDeviation();
  error OracleNotInitialized();
  error EmergencyModeActive();
  error InvalidDeviation();

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════════════════════════

  constructor(
    string memory _nativeSymbol,
    string memory _quoteSymbol,
    address _initialOwner,
    address _registry,
    address _dragonToken
  ) Ownable(_initialOwner) {
    nativeSymbol = _nativeSymbol;
    quoteSymbol = _quoteSymbol;
    deploymentTime = block.timestamp;
    registry = IOmniDragonRegistry(_registry);
    dragonToken = _dragonToken;

    // Initialize with default weights (can be changed later)
    chainlinkConfig = OracleConfig({
      feedAddress: address(0),
      weight: 4000, // 40%
      isActive: false,
      maxStaleness: DEFAULT_MAX_STALENESS
    });

    bandConfig = OracleConfig({
      feedAddress: address(0),
      weight: 3000, // 30%
      isActive: false,
      maxStaleness: DEFAULT_MAX_STALENESS
    });

    api3Config = OracleConfig({
      feedAddress: address(0),
      weight: 2000, // 20%
      isActive: false,
      maxStaleness: DEFAULT_MAX_STALENESS
    });

    pythConfig = OracleConfig({
      feedAddress: address(0),
      weight: 1000, // 10%
      isActive: false,
      maxStaleness: DEFAULT_MAX_STALENESS
    });

    // DON'T initialize price here - wait for proper initialization
    latestPrice = 0;
    lastPriceUpdate = 0;
    isInitialized = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // MAIN FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════════════════

  /**
   * @dev Get the latest aggregated price
   */
  function getLatestPrice() external view returns (int256 price, uint256 timestamp) {
    if (emergencyMode) {
      return (emergencyPrice, block.timestamp);
    }

    if (circuitBreakerActive) revert CircuitBreakerActive();
    if (!isInitialized) revert OracleNotInitialized();
    if (block.timestamp - lastPriceUpdate > DEFAULT_MAX_STALENESS) revert PriceDataStale();

    return (latestPrice, lastPriceUpdate);
  }

  /**
   * @dev Get aggregated price (alternative interface for compatibility)
   */
  function getAggregatedPrice() external view returns (int256 price, bool success, uint256 timestamp) {
    if (emergencyMode) {
      return (emergencyPrice, true, block.timestamp);
    }

    if (circuitBreakerActive || !isInitialized) {
      return (0, false, 0);
    }

    if (block.timestamp - lastPriceUpdate > DEFAULT_MAX_STALENESS) {
      return (0, false, 0);
    }

    return (latestPrice, true, lastPriceUpdate);
  }

  /**
   * @notice Get the native token price (e.g., SONIC/USD, ETH/USD)
   * @return price The price of native token in USD (8 decimals)
   * @return isValid Whether the price is valid
   * @return timestamp The timestamp of the price
   */
  function getNativeTokenPrice() external view returns (int256 price, bool isValid, uint256 timestamp) {
    address feed = nativeTokenPriceFeeds[block.chainid];
    if (feed == address(0)) {
      // No feed configured for this chain
      return (0, false, 0);
    }

    try IChainlinkAggregator(feed).latestRoundData() returns (
      uint80,
      int256 _price,
      uint256,
      uint256 _timestamp,
      uint80
    ) {
      // Validate price
      if (_price <= 0 || _timestamp == 0) {
        return (0, false, 0);
      }

      // Check staleness (1 hour)
      if (block.timestamp - _timestamp > 3600) {
        return (0, false, 0);
      }

      return (_price, true, _timestamp);
    } catch {
      return (0, false, 0);
    }
  }

  /**
   * @notice Admin function to set native token price feed
   * @param chainId The chain ID
   * @param feed The Chainlink price feed address
   */
  function setNativeTokenPriceFeed(uint256 chainId, address feed) external onlyOwner {
    nativeTokenPriceFeeds[chainId] = feed;
  }

  /**
   * @dev Initialize the oracle with current market price (one-time setup)
   */
  function initializePrice() external onlyOwner returns (bool success) {
    if (isInitialized) {
      return updatePrice(); // Already initialized, just update
    }

    (int256 marketPrice, bool priceValid) = _getWeightedAveragePrice();

    if (!priceValid) {
      revert NoValidOracleData();
    }

    // First initialization - no deviation check
    latestPrice = marketPrice;
    lastPriceUpdate = block.timestamp;
    isInitialized = true;

    emit PriceInitialized(marketPrice, block.timestamp);
    emit PriceUpdated(marketPrice, block.timestamp, _getActiveOracleCount());

    return true;
  }

  /**
   * @dev Update price from all configured oracles
   */
  function updatePrice() public virtual nonReentrant returns (bool success) {
    if (emergencyMode) revert EmergencyModeActive();
    if (circuitBreakerActive) return false;

    (int256 newPrice, bool priceValid) = _getWeightedAveragePrice();

    if (!priceValid) {
      revert NoValidOracleData();
    }

    // Check for excessive price deviation (unless in grace period)
    if (isInitialized && !_isInGracePeriod()) {
      uint256 deviation = _calculateDeviation(latestPrice, newPrice);
      if (deviation > maxPriceDeviation) {
        circuitBreakerActive = true;
        emit CircuitBreakerTriggered("Excessive price deviation", latestPrice, newPrice, deviation);
        return false;
      }
    }

    // Update price
    latestPrice = newPrice;
    lastPriceUpdate = block.timestamp;

    if (!isInitialized) {
      isInitialized = true;
      emit PriceInitialized(newPrice, block.timestamp);
    }

    emit PriceUpdated(newPrice, block.timestamp, _getActiveOracleCount());
    return true;
  }

  /**
   * @dev Get weighted average price from all active oracles
   */
  function _getWeightedAveragePrice() internal view returns (int256 price, bool isValid) {
    uint256 totalWeight = 0;
    uint256 weightedSum = 0;
    uint256 validOracles = 0;

    // Get price from Chainlink
    if (chainlinkConfig.isActive) {
      (int256 oraclePrice, bool valid) = _getChainlinkPrice();
      if (valid) {
        weightedSum += uint256(oraclePrice) * chainlinkConfig.weight;
        totalWeight += chainlinkConfig.weight;
        validOracles++;
      }
    }

    // Get price from Band Protocol
    if (bandConfig.isActive) {
      (int256 oraclePrice, bool valid) = _getBandPrice();
      if (valid) {
        weightedSum += uint256(oraclePrice) * bandConfig.weight;
        totalWeight += bandConfig.weight;
        validOracles++;
      }
    }

    // Get price from API3
    if (api3Config.isActive) {
      (int256 oraclePrice, bool valid) = _getAPI3Price();
      if (valid) {
        weightedSum += uint256(oraclePrice) * api3Config.weight;
        totalWeight += api3Config.weight;
        validOracles++;
      }
    }

    // Get price from Pyth
    if (pythConfig.isActive) {
      (int256 oraclePrice, bool valid) = _getPythPrice();
      if (valid) {
        weightedSum += uint256(oraclePrice) * pythConfig.weight;
        totalWeight += pythConfig.weight;
        validOracles++;
      }
    }

    if (validOracles == 0 || totalWeight == 0) {
      return (0, false);
    }

    // Calculate weighted average
    price = int256(weightedSum / totalWeight);
    isValid = true;
  }

  /**
   * @dev Check if we're in the initialization grace period
   */
  function _isInGracePeriod() internal view returns (bool) {
    return block.timestamp < deploymentTime + initializationGracePeriod;
  }

  /**
   * @dev Get count of active oracles
   */
  function _getActiveOracleCount() internal view returns (uint256) {
    uint256 count = 0;
    if (chainlinkConfig.isActive) count++;
    if (bandConfig.isActive) count++;
    if (api3Config.isActive) count++;
    if (pythConfig.isActive) count++;
    return count;
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ORACLE PRICE GETTERS
  // ═══════════════════════════════════════════════════════════════════════════════════════

  function _getChainlinkPrice() internal view returns (int256 price, bool isValid) {
    if (chainlinkConfig.feedAddress == address(0)) return (0, false);

    try IChainlinkAggregator(chainlinkConfig.feedAddress).latestRoundData() returns (
      uint80,
      int256 answer,
      uint256,
      uint256 updatedAt,
      uint80
    ) {
      if (answer <= 0 || updatedAt == 0) return (0, false);
      if (block.timestamp - updatedAt > chainlinkConfig.maxStaleness) return (0, false);

      // Convert to 18 decimals
      uint8 decimals = IChainlinkAggregator(chainlinkConfig.feedAddress).decimals();
      if (decimals < 18) {
        price = answer * int256(10 ** (18 - decimals));
      } else if (decimals > 18) {
        price = answer / int256(10 ** (decimals - 18));
      } else {
        price = answer;
      }

      return (price, true);
    } catch {
      return (0, false);
    }
  }

  function _getBandPrice() internal view returns (int256 price, bool isValid) {
    if (bandConfig.feedAddress == address(0)) return (0, false);

    try IStdReference(bandConfig.feedAddress).getReferenceData(bandProtocolBaseSymbol, "USD") returns (
      IStdReference.ReferenceData memory data
    ) {
      if (data.rate == 0) return (0, false);
      if (block.timestamp - data.lastUpdatedBase > bandConfig.maxStaleness) return (0, false);

      price = int256(data.rate);
      return (price, true);
    } catch {
      return (0, false);
    }
  }

  function _getAPI3Price() internal view returns (int256 price, bool isValid) {
    if (api3Config.feedAddress == address(0)) return (0, false);

    try IApi3ReaderProxy(api3Config.feedAddress).read() returns (int224 value, uint32 timestamp) {
      if (value <= 0 || timestamp == 0) return (0, false);
      if (block.timestamp - timestamp > api3Config.maxStaleness) return (0, false);

      price = int256(value);
      return (price, true);
    } catch {
      return (0, false);
    }
  }

  function _getPythPrice() internal view returns (int256 price, bool isValid) {
    if (pythConfig.feedAddress == address(0) || pythPriceId == bytes32(0)) return (0, false);

    try IPyth(pythConfig.feedAddress).getPriceUnsafe(pythPriceId) returns (PythStructs.Price memory pythPrice) {
      if (pythPrice.price <= 0) return (0, false);
      if (block.timestamp - pythPrice.publishTime > pythConfig.maxStaleness) return (0, false);

      // Convert to 18 decimals
      int256 adjustedPrice;
      if (pythPrice.expo < 0) {
        uint256 negativeExpo = uint256(-int256(pythPrice.expo));
        if (negativeExpo <= 18) {
          adjustedPrice = int256(pythPrice.price) * int256(10 ** (18 - negativeExpo));
        } else {
          adjustedPrice = int256(pythPrice.price) / int256(10 ** (negativeExpo - 18));
        }
      } else {
        uint256 positiveExpo = uint256(int256(pythPrice.expo));
        if (positiveExpo >= 18) {
          adjustedPrice = int256(pythPrice.price) / int256(10 ** (positiveExpo - 18));
        } else {
          adjustedPrice = int256(pythPrice.price) * int256(10 ** (18 - positiveExpo));
        }
      }

      return (adjustedPrice, true);
    } catch {
      return (0, false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // ADMIN FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════════════════

  /**
   * @dev Configure oracle addresses and settings
   */
  function configureOracles(
    address _chainlinkFeed,
    address _bandFeed,
    address _api3Feed,
    address _pythFeed,
    bytes32 _pythPriceId,
    string calldata _bandBaseSymbol
  ) external onlyOwner {
    // Update addresses
    chainlinkConfig.feedAddress = _chainlinkFeed;
    chainlinkConfig.isActive = _chainlinkFeed != address(0);

    bandConfig.feedAddress = _bandFeed;
    bandConfig.isActive = _bandFeed != address(0);

    api3Config.feedAddress = _api3Feed;
    api3Config.isActive = _api3Feed != address(0);

    pythConfig.feedAddress = _pythFeed;
    pythConfig.isActive = _pythFeed != address(0);

    // Update network-specific settings
    pythPriceId = _pythPriceId;
    bandProtocolBaseSymbol = _bandBaseSymbol;

    emit OracleConfigUpdated("chainlink", _chainlinkFeed, chainlinkConfig.weight);
    emit OracleConfigUpdated("band", _bandFeed, bandConfig.weight);
    emit OracleConfigUpdated("api3", _api3Feed, api3Config.weight);
    emit OracleConfigUpdated("pyth", _pythFeed, pythConfig.weight);
  }

  /**
   * @dev Set oracle weights (must sum to 10000)
   */
  function setOracleWeights(
    uint256 _chainlinkWeight,
    uint256 _bandWeight,
    uint256 _api3Weight,
    uint256 _pythWeight
  ) external onlyOwner {
    if (_chainlinkWeight + _bandWeight + _api3Weight + _pythWeight != 10000) {
      revert InvalidWeights();
    }

    chainlinkConfig.weight = _chainlinkWeight;
    bandConfig.weight = _bandWeight;
    api3Config.weight = _api3Weight;
    pythConfig.weight = _pythWeight;

    emit OracleConfigUpdated("weights", address(0), 10000);
  }

  /**
   * @dev Set maximum price deviation threshold
   */
  function setMaxPriceDeviation(uint256 _maxDeviation) external onlyOwner {
    if (_maxDeviation > 10000) revert InvalidDeviation(); // Max 100%

    uint256 oldDeviation = maxPriceDeviation;
    maxPriceDeviation = _maxDeviation;

    emit MaxDeviationUpdated(oldDeviation, _maxDeviation);
  }

  /**
   * @dev Set initialization grace period
   */
  function setInitializationGracePeriod(uint256 _gracePeriod) external onlyOwner {
    initializationGracePeriod = _gracePeriod;
  }

  /**
   * @dev Reset circuit breaker
   */
  function resetCircuitBreaker() external onlyOwner {
    circuitBreakerActive = false;
    emit CircuitBreakerReset(msg.sender);
  }

  /**
   * @dev Emergency mode - allows owner to set fixed price
   */
  function activateEmergencyMode(int256 _emergencyPrice) external onlyOwner {
    emergencyMode = true;
    emergencyPrice = _emergencyPrice;
    emit EmergencyModeActivated(_emergencyPrice);
  }

  /**
   * @dev Deactivate emergency mode
   */
  function deactivateEmergencyMode() external onlyOwner {
    emergencyMode = false;
    emergencyPrice = 0;
    emit EmergencyModeDeactivated();
  }

  /**
   * @dev Pause the contract
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @dev Unpause the contract
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // UTILITY FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════════════════════════

  function _calculateDeviation(int256 oldPrice, int256 newPrice) internal pure returns (uint256) {
    if (oldPrice == 0) return 0;

    int256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
    return uint256((diff * 10000) / oldPrice);
  }

  /**
   * @dev Get oracle configuration
   */
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
    )
  {
    return (chainlinkConfig, bandConfig, api3Config, pythConfig, bandProtocolBaseSymbol, pythPriceId);
  }

  /**
   * @dev Check if price data is fresh
   */
  function isFresh() external view returns (bool) {
    if (emergencyMode) return true;
    return isInitialized && (block.timestamp - lastPriceUpdate) <= DEFAULT_MAX_STALENESS && !circuitBreakerActive;
  }

  /**
   * @dev Get current oracle status
   */
  function getOracleStatus()
    external
    view
    returns (
      bool initialized,
      bool circuitBreakerActive_,
      bool emergencyMode_,
      bool inGracePeriod,
      uint256 activeOracles,
      uint256 maxDeviation
    )
  {
    return (
      isInitialized,
      circuitBreakerActive,
      emergencyMode,
      _isInGracePeriod(),
      _getActiveOracleCount(),
      maxPriceDeviation
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════════════
  // LP TOKEN PRICING
  // ═══════════════════════════════════════════════════════════════════════════════════════

  /**
   * @notice Calculate USD value of LP tokens using Fair Value method
   * @dev Calculates based on underlying reserves multiplied by token prices
   * @param lpToken Address of the Uniswap V2 pair
   * @param amount Amount of LP tokens (18 decimals)
   * @return usdValue USD value (6 decimals)
   */
  function getLPTokenPrice(address lpToken, uint256 amount) external view returns (uint256 usdValue) {
    if (lpToken == address(0) || amount == 0) return 0;

    IUniswapV2Pair pair = IUniswapV2Pair(lpToken);

    // Step 1: Get reserves and total supply
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
    uint256 totalSupply = pair.totalSupply();

    if (totalSupply == 0) return 0;

    // Step 2: Get token addresses
    address token0 = pair.token0();
    address token1 = pair.token1();

    // Step 3: Calculate Total Value Locked (TVL) in USD
    uint256 tvl = 0;

    // Get USD value of token0 reserves
    uint256 value0 = _getTokenValue(token0, uint256(reserve0));

    // Get USD value of token1 reserves
    uint256 value1 = _getTokenValue(token1, uint256(reserve1));

    // TVL = sum of both token values
    tvl = value0 + value1;

    // Step 4: Calculate LP token price
    // LP Price = (TVL * amount) / totalSupply
    // TVL is in 6 decimals, amount and totalSupply are in 18 decimals
    // Result should be in 6 decimals
    usdValue = (tvl * amount) / totalSupply;
  }

  /**
   * @dev Get USD value of a token amount
   * @param token Token address
   * @param amount Token amount (18 decimals)
   * @return USD value (6 decimals)
   */
  function _getTokenValue(address token, uint256 amount) internal view returns (uint256) {
    if (amount == 0) return 0;

    // Check if it's DRAGON token
    if (token == dragonToken) {
      (int256 price, bool success, uint256 timestamp) = this.getAggregatedPrice();
      if (success && price > 0 && _isPriceFresh(timestamp)) {
        // amount is 18 decimals, price is 8 decimals, want 6 decimals
        // 18 + 8 - 6 = 20
        return (amount * uint256(price)) / 1e20;
      }
    }
    // Check if it's wrapped native token
    else if (_isWrappedNative(token)) {
      (int256 price, bool success, uint256 timestamp) = this.getNativeTokenPrice();
      if (success && price > 0 && _isPriceFresh(timestamp)) {
        // amount is 18 decimals, price is 8 decimals, want 6 decimals
        return (amount * uint256(price)) / 1e20;
      }
    }
    // For other tokens, would need additional price feeds
    return 0;
  }

  /**
   * @dev Check if a token is the wrapped native token for current chain
   * @param token Token address to check
   * @return True if token is wrapped native
   */
  function _isWrappedNative(address token) internal view returns (bool) {
    if (address(registry) == address(0)) return false;

    try registry.getWrappedNativeToken(uint16(block.chainid)) returns (address wrappedNative) {
      return token == wrappedNative;
    } catch {
      return false;
    }
  }

  /**
   * @dev Check if price timestamp is fresh enough
   * @param timestamp Price update timestamp
   * @return True if price is fresh
   */
  function _isPriceFresh(uint256 timestamp) internal view returns (bool) {
    return (block.timestamp - timestamp) <= DEFAULT_MAX_STALENESS;
  }
}