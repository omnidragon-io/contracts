// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IredDRAGON
 * @dev Interface for redDRAGON - An ERC-4626 vault for Uniswap V2 LP tokens with lottery integration
 *
 * OVERVIEW:
 * redDRAGON is an ERC-4626 vault that represents ownership of underlying DRAGON/wrappedNative LP tokens.
 * As LP tokens auto-compound through trading fees, redDRAGON shares maintain proper accounting.
 * When users buy/sell redDRAGON through DEX pairs, it triggers:
 * 1. Immediate fee collection (6.9% of transaction amount)
 * 2. Immediate fee distribution (69% to jackpot, 31% to veDRAGON holders)
 * 3. Lottery entry based on transaction value (BUYS ONLY)
 *
 * ERC-4626 VAULT MECHANICS:
 * - Shares represent proportional ownership of LP tokens
 * - As LP tokens appreciate from trading fees, shares become worth more LP tokens
 * - Standard vault functions: deposit, withdraw, mint, redeem
 * - Preview functions show expected conversions
 */
interface IredDRAGON {
  // ========== STRUCTS ==========

  struct SwapConfig {
    address jackpotVault; // Jackpot vault address
    address revenueDistributor; // veDRAGON revenue distributor
    address lotteryManager; // Lottery manager for entries
  }

  struct LotteryConfig {
    uint256 minSwapUSD; // Minimum USD swap amount for lottery entry
    uint256 maxSwapUSD; // Maximum USD swap amount for max probability
    uint256 minProbabilityPPM; // Minimum probability in parts per million
    uint256 maxProbabilityPPM; // Maximum probability in parts per million
    bool enabled; // Whether lottery is enabled
  }

  // ========== EVENTS ==========

  event TradingEnabled(uint256 timestamp);
  event TradingPaused(uint256 timestamp);
  event PairUpdated(address indexed pair, bool indexed isPair);
  event FeeExclusionUpdated(address indexed account, bool excluded);

  // ========== INITIALIZATION ==========

  /**
   * @notice Initialize the contract (called once after deployment)
   * @param _owner Owner address
   * @param _jackpotVault Jackpot vault address
   * @param _revenueDistributor veDRAGON revenue distributor
   * @param _lotteryManager Lottery manager address
   */
  function initialize(
    address _owner,
    address _jackpotVault,
    address _revenueDistributor,
    address _lotteryManager
  ) external;

  // ========== VIEW FUNCTIONS ==========

  /**
   * @notice Get current swap configuration
   * @return config Current swap configuration
   */
  function getSwapConfig() external view returns (SwapConfig memory config);

  /**
   * @notice Get current lottery configuration
   * @return config Current lottery configuration
   */
  function getLotteryConfig() external view returns (LotteryConfig memory config);

  /**
   * @notice Get USD value of redDRAGON shares (simplified - no oracle needed)
   * @param token Token address (ignored)
   * @param amount Amount of redDRAGON shares
   * @return usdValue USD value (always returns 0 for simplicity)
   */
  function getUSDValue(address token, uint256 amount) external view returns (uint256 usdValue);

  /**
   * @notice Check if address is authorized swap contract (deprecated)
   * @param swapContract Swap contract address
   * @return authorized Whether address is authorized (always false)
   */
  function isAuthorizedSwapContract(address swapContract) external view returns (bool authorized);

  /**
   * @notice Get total fees collected
   * @return jackpotFees Total fees sent to jackpot
   * @return revenueFees Total fees sent to revenue distributor
   */
  function getTotalFees() external view returns (uint256 jackpotFees, uint256 revenueFees);

  /**
   * @notice Check if contract is initialized
   * @return initialized Whether contract is initialized
   */
  function isInitialized() external view returns (bool);
}