// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOmniDragonRegistry
 * @dev Interface for OmniDragon registry with oracle management
 */
interface IOmniDragonRegistry {
  /**
   * @dev Simplified struct to hold essential chain configuration
   */
  struct ChainConfig {
    uint16 chainId;
    string chainName;
    address wrappedNativeToken; // WETH, WAVAX, WS, etc.
    string wrappedNativeSymbol; // "WETH", "WAVAX", "WS", etc.
    address uniswapV2Router; // DEX router for this chain
    address uniswapV2Factory; // DEX factory for this chain
    bool isActive; // Whether this chain is active
  }

  /**
   * @dev Oracle configuration struct
   */
  struct OracleConfig {
    address primaryOracle;      // Primary oracle address (Sonic chain)
    uint32 primaryChainEid;    // Primary chain EID
    uint32 lzReadChannelId;    // lzRead channel ID
    bool isConfigured;         // Whether oracle is configured
  }

  // Events
  event ChainRegistered(uint16 indexed chainId, string chainName);
  event ChainUpdated(uint16 indexed chainId);
  event ChainStatusChanged(uint16 indexed chainId, bool isActive);
  
  // Oracle events
  event PriceOracleSet(uint16 indexed chainId, address indexed oracle);
  event PrimaryOracleConfigured(address indexed primaryOracle, uint32 chainEid);
  event LzReadChannelConfigured(uint16 indexed chainId, uint32 channelId);

  /**
   * @notice Register a new chain configuration
   * @param _chainId The chain ID
   * @param _chainName The human-readable chain name
   * @param _wrappedNativeToken The wrapped native token address
   * @param _uniswapV2Router The Uniswap V2 router address
   * @param _uniswapV2Factory The Uniswap V2 factory address
   * @param _isActive Whether this chain is active
   */
  function registerChain(
    uint16 _chainId,
    string calldata _chainName,
    address _wrappedNativeToken,
    address _uniswapV2Router,
    address _uniswapV2Factory,
    bool _isActive
  ) external;

  /**
   * @notice Update existing chain configuration
   * @param _chainId The chain ID to update
   * @param _chainName The human-readable chain name
   * @param _wrappedNativeToken The wrapped native token address
   * @param _uniswapV2Router The Uniswap V2 router address
   * @param _uniswapV2Factory The Uniswap V2 factory address
   */
  function updateChain(
    uint16 _chainId,
    string calldata _chainName,
    address _wrappedNativeToken,
    address _uniswapV2Router,
    address _uniswapV2Factory
  ) external;

  /**
   * @notice Set chain active status
   * @param _chainId The chain ID
   * @param _isActive Whether the chain should be active
   */
  function setChainStatus(uint16 _chainId, bool _isActive) external;

  /**
   * @notice Get chain configuration
   * @param _chainId The chain ID
   * @return config The chain configuration
   */
  function getChainConfig(uint16 _chainId) external view returns (ChainConfig memory config);

  /**
   * @notice Get all supported chains
   * @return Array of supported chain IDs
   */
  function getSupportedChains() external view returns (uint16[] memory);

  /**
   * @notice Get current chain ID
   * @return The current chain ID
   */
  function getCurrentChainId() external view returns (uint16);

  /**
   * @notice Check if chain is supported and active
   * @param _chainId The chain ID to check
   * @return True if chain is supported and active
   */
  function isChainSupported(uint16 _chainId) external view returns (bool);

  /**
   * @notice Get wrapped native token address for a chain
   * @param _chainId The chain ID
   * @return The wrapped native token address
   */
  function getWrappedNativeToken(uint16 _chainId) external view returns (address);

  /**
   * @notice Get wrapped native token symbol for a chain
   * @param _chainId The chain ID
   * @return The wrapped native token symbol
   */
  function getWrappedNativeSymbol(uint16 _chainId) external view returns (string memory);

  /**
   * @notice Get Uniswap V2 router for a chain
   * @param _chainId The chain ID
   * @return The Uniswap V2 router address
   */
  function getUniswapV2Router(uint16 _chainId) external view returns (address);

  /**
   * @notice Get Uniswap V2 factory for a chain
   * @param _chainId The chain ID
   * @return The Uniswap V2 factory address
   */
  function getUniswapV2Factory(uint16 _chainId) external view returns (address);

  /**
   * @notice Get LayerZero endpoint for a chain
   * @param _chainId The chain ID
   * @return The LayerZero endpoint address
   */
  function getLayerZeroEndpoint(uint16 _chainId) external view returns (address);

  // ============ ORACLE MANAGEMENT ============

  /**
   * @notice Set price oracle for a specific chain
   * @param _chainId Chain ID
   * @param _oracle Oracle address
   */
  function setPriceOracle(uint16 _chainId, address _oracle) external;

  /**
   * @notice Get price oracle for a specific chain
   * @param _chainId Chain ID
   * @return Oracle address
   */
  function getPriceOracle(uint16 _chainId) external view returns (address);

  /**
   * @notice Configure primary oracle (on Sonic chain)
   * @param _primaryOracle Primary oracle address
   * @param _chainEid Primary chain EID
   */
  function configurePrimaryOracle(address _primaryOracle, uint32 _chainEid) external;

  /**
   * @notice Set lzRead channel for a chain
   * @param _chainId Chain ID
   * @param _channelId lzRead channel ID
   */
  function setLzReadChannel(uint16 _chainId, uint32 _channelId) external;

  /**
   * @notice Get oracle configuration for a chain
   * @param _chainId Chain ID
   * @return Oracle configuration
   */
  function getOracleConfig(uint16 _chainId) external view returns (OracleConfig memory);
} 