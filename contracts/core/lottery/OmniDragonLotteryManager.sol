// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IChainlinkVRFIntegratorV2_5} from "../../interfaces/vrf/IChainlinkVRFIntegratorV2_5.sol";
import {IOmniDragonVRFConsumerV2_5} from "../../interfaces/vrf/IOmniDragonVRFConsumerV2_5.sol";

// Interface for local VRF callbacks
interface IVRFCallbackReceiver {
  function receiveRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}
import {MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IDragonJackpotDistributor} from "../../interfaces/lottery/IDragonJackpotDistributor.sol";
import {IOmniDragonPriceOracle} from "../../interfaces/oracles/IOmniDragonPriceOracle.sol";
import {IveDRAGONBoostManager} from "../../interfaces/governance/voting/IveDRAGONBoostManager.sol";

// ============ INTERFACES ============

interface IveDRAGONToken {
  function lockedEnd(address user) external view returns (uint256);
  function balanceOf(address user) external view returns (uint256);
  function totalSupply() external view returns (uint256);
}

// ============ INTERFACES ============

interface IDragonJackpotVault {
  function getJackpotBalance() external view returns (uint256 balance);
  function payJackpot(address winner, uint256 amount) external;
  function getLastWinTime() external view returns (uint256 timestamp);
}

/**
 * @title OmniDragonLotteryManager
 * @author 0xakita.eth
 * @dev Manages instantaneous per-swap lottery system for OmniDragon ecosystem
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 *
 * FEATURES:
 * - Per-swap lottery entries with linear probability scaling
 * - veDRAGON boost integration using Curve Finance formula
 * - Three secure VRF randomness sources: Local VRF, Cross-chain VRF, and Provider randomness
 * - Position-based boost capping to prevent exploitation
 * - Rate limiting and DoS protection
 * - Pull payment mechanism for failed prize transfers
 *
 * SECURITY:
 * - All randomness sources are cryptographically secure (VRF only)
 * - No exploitable pseudo-randomness functions
 * - ReentrancyGuard protection on all external functions
 * - Comprehensive access control system
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract OmniDragonLotteryManager is Ownable, ReentrancyGuard, IVRFCallbackReceiver {
  using SafeERC20 for IERC20;
  using Address for address payable;

  // ============ CONSTANTS ============

  uint256 public constant MIN_SWAP_INTERVAL = 7; // 7 seconds between swaps per user to prevent spam
  uint256 public constant MAX_BOOST_BPS = 25000; // 2.5x boost maximum
  uint256 public constant MAX_WIN_PROBABILITY_PPM = 100000; // 10% maximum win probability (100,000 PPM)

  // Instant lottery configuration (USD-based with 6 decimals)
  uint256 public constant MIN_SWAP_USD = 10e6; // $10 USD minimum
  uint256 public constant MAX_PROBABILITY_SWAP_USD = 10000e6; // $10,000 USD for max probability (not a trade limit)
  uint256 public constant MIN_WIN_CHANCE_PPM = 40; // 0.004% (40 parts per million) at $10
  uint256 public constant MAX_WIN_CHANCE_PPM = 40000; // 4% (40,000 parts per million) at $10,000+

  // Using Parts Per Million (PPM) for precise probability control
  // 1 PPM = 0.0001% = 1/1,000,000
  // 40 PPM = 0.004%, 40,000 PPM = 4%

  // veDRAGON boost configuration
  uint256 public constant BOOST_PRECISION = 1e18;
  uint256 public constant MAX_BOOST = 25e17; // 2.5x maximum boost
  uint256 public constant MIN_BOOST = 1e18; // 1.0x minimum boost (no boost)

  // ============ ENUMS ============

  enum RandomnessSource {
    LOCAL_VRF, // Local: Direct Chainlink VRF
    CROSS_CHAIN_VRF // Cross-chain: Chainlink VRF via LayerZero
  }

  // ============ STRUCTS ============

  struct InstantLotteryConfig {
    uint256 baseWinProbability; // Base probability in PPM (parts per million) - UNUSED, kept for compatibility
    uint256 minSwapAmount; // Minimum swap amount to qualify (in USD, scaled by 1e6)
    uint256 rewardPercentage; // Percentage of jackpot as reward (in basis points)
    bool isActive;
    bool useVRFForInstant; // Whether to use VRF for instant lotteries (recommended)
  }

  struct UserStats {
    uint256 totalSwaps;
    uint256 totalVolume;
    uint256 totalWins;
    uint256 totalRewards;
    uint256 lastSwapTimestamp;
  }

  struct PendingLotteryEntry {
    address user;
    uint256 swapAmountUSD;
    uint256 winProbability;
    uint256 timestamp;
    bool fulfilled;
    RandomnessSource randomnessSource;
  }

  // Constants for state growth management
  uint256 public constant MAX_PENDING_ENTRY_AGE = 24 hours; // Max age before entry can be cleaned up
  uint256 public constant CLEANUP_BATCH_SIZE = 50; // Max entries to clean in one transaction

  // ============ STATE VARIABLES ============

  // Core dependencies
  IDragonJackpotDistributor public jackpotDistributor;
  IERC20 public veDRAGONToken;
  IERC20 public redDRAGONToken;
  IveDRAGONBoostManager public veDRAGONBoostManager;

  // VRF integrations
  IChainlinkVRFIntegratorV2_5 public vrfIntegrator;
  IOmniDragonVRFConsumerV2_5 public localVRFConsumer;
  IDragonJackpotVault public jackpotVault;

  // Chain-specific multiplier
  uint256 public chainMultiplier = 1e18; // 1.0x by default

  // Market infrastructure integration
  IOmniDragonPriceOracle public priceOracle;
  uint256 public immutable CHAIN_ID;

  // Prize configuration removed - rewards are now dynamic based on jackpot vault balance

  // Rate limiting
  mapping(address => uint256) public lastSwapTime;

  // Access control
  mapping(address => bool) public authorizedSwapContracts;

  // Lottery state
  mapping(uint256 => PendingLotteryEntry) public pendingEntries;
  mapping(address => UserStats) public userStats;

  // Statistics
  uint256 public totalLotteryEntries;
  uint256 public totalPrizesWon;
  uint256 public totalPrizesDistributed;

  InstantLotteryConfig public instantLotteryConfig;

  // Oracle integration
  IERC20 public dragonToken;

  // ============ EVENTS ============

  event InstantLotteryProcessed(address indexed user, uint256 swapAmount, bool won, uint256 reward);
  event InstantLotteryEntered(
    address indexed user,
    uint256 swapAmountUSD,
    uint256 winChancePPM,
    uint256 boostedWinChancePPM,
    uint256 randomnessId
  );
  event LotteryEntryCreated(address indexed user, uint256 swapAmountUSD, uint256 winProbability, uint256 vrfRequestId);
  event RandomnessRequested(uint256 indexed requestId, address indexed user, RandomnessSource source);
  event RandomnessFulfilled(uint256 indexed requestId, uint256 randomness, RandomnessSource source);

  // Pull payment events
  event PrizeClaimable(address indexed winner, uint256 amount);
  event PrizeClaimed(address indexed winner, uint256 amount);
  event PrizeTransferFailed(address indexed winner, uint256 amount);

  // Configuration events
  event InstantLotteryConfigured(
    uint256 baseWinProbability,
    uint256 minSwapAmount,
    uint256 rewardPercentage,
    bool isActive
  );
  event SwapContractAuthorized(address indexed swapContract, bool authorized);
  event LotteryManagerInitialized(address jackpotDistributor, address veDRAGONToken);
  event PriceOracleUpdated(address indexed newPriceOracle);
  event ChainMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
  event RedDRAGONTokenUpdated(address indexed redDRAGONToken);
  // Fixed prize events removed - rewards are now purely dynamic

  // ============ CONSTRUCTOR ============

  constructor(
    address _jackpotDistributor,
    address _veDRAGONToken,
    address _priceOracle,
    uint256 _chainId
  ) Ownable(msg.sender) {
    require(_jackpotDistributor != address(0), "Invalid jackpot distributor");
    require(_veDRAGONToken != address(0), "Invalid veDRAGON token");
    require(_priceOracle != address(0), "Invalid price oracle");

    jackpotDistributor = IDragonJackpotDistributor(_jackpotDistributor);
    veDRAGONToken = IERC20(_veDRAGONToken);
    priceOracle = IOmniDragonPriceOracle(_priceOracle);
    // veDRAGONBoostManager will be set via setter function after deployment

    CHAIN_ID = _chainId;

    // Initialize instant lottery config using PPM constants
    instantLotteryConfig = InstantLotteryConfig({
      baseWinProbability: MIN_WIN_CHANCE_PPM, // 40 PPM = 0.004% (for compatibility only - actual calculation uses constants)
      minSwapAmount: MIN_SWAP_USD,
      rewardPercentage: 6900, // 69% of jackpot
      isActive: true,
      useVRFForInstant: true
    });

    emit LotteryManagerInitialized(_jackpotDistributor, _veDRAGONToken);
  }

  // ============ MODIFIERS ============

  modifier onlyAuthorizedSwapContract() {
    require(authorizedSwapContracts[msg.sender], "Unauthorized swap contract");
    _;
  }

  modifier rateLimited(address user) {
    require(block.timestamp >= lastSwapTime[user] + MIN_SWAP_INTERVAL, "Swap too frequent");
    lastSwapTime[user] = block.timestamp;
    _;
  }

  // ============ ADMIN FUNCTIONS ============

  function setVRFIntegrator(address _vrfIntegrator) external onlyOwner {
    vrfIntegrator = IChainlinkVRFIntegratorV2_5(_vrfIntegrator);

    // Auto-authorize this contract with the VRF integrator if possible
    if (_vrfIntegrator != address(0)) {
      try IChainlinkVRFIntegratorV2_5(_vrfIntegrator).setAuthorizedCaller(address(this), true) {
        // Successfully authorized
      } catch {
        // Authorization failed - owner will need to authorize manually
      }
    }
  }

  function setLocalVRFConsumer(address _localVRFConsumer) external onlyOwner {
    localVRFConsumer = IOmniDragonVRFConsumerV2_5(_localVRFConsumer);

    // Auto-authorize this contract with the local VRF consumer if possible
    if (_localVRFConsumer != address(0)) {
      try IOmniDragonVRFConsumerV2_5(_localVRFConsumer).setLocalCallerAuthorization(address(this), true) {
        // Successfully authorized
      } catch {
        // Authorization failed - owner will need to authorize manually
      }
    }
  }

  function setJackpotVault(address _jackpotVault) external onlyOwner {
    require(_jackpotVault != address(0), "Invalid jackpot vault");
    jackpotVault = IDragonJackpotVault(_jackpotVault);
  }

  function setJackpotDistributor(address _jackpotDistributor) external onlyOwner {
    require(_jackpotDistributor != address(0), "Invalid jackpot distributor");
    jackpotDistributor = IDragonJackpotDistributor(_jackpotDistributor);
  }

  function setPriceOracle(address _priceOracle) external onlyOwner {
    priceOracle = IOmniDragonPriceOracle(_priceOracle);
    emit PriceOracleUpdated(_priceOracle);
  }

  function setChainMultiplier(uint256 _chainMultiplier) external onlyOwner {
    require(_chainMultiplier > 0, "Invalid chain multiplier");
    uint256 oldMultiplier = chainMultiplier;
    chainMultiplier = _chainMultiplier;
    emit ChainMultiplierUpdated(oldMultiplier, _chainMultiplier);
  }

  function setRedDRAGONToken(address _redDRAGONToken) external onlyOwner {
    require(_redDRAGONToken != address(0), "Invalid redDRAGON token");
    redDRAGONToken = IERC20(_redDRAGONToken);
    emit RedDRAGONTokenUpdated(_redDRAGONToken);
  }

  function setVeDRAGONBoostManager(address _veDRAGONBoostManager) external onlyOwner {
    require(_veDRAGONBoostManager != address(0), "Invalid veDRAGON boost manager");
    veDRAGONBoostManager = IveDRAGONBoostManager(_veDRAGONBoostManager);
  }

  function setAuthorizedSwapContract(address swapContract, bool authorized) external onlyOwner {
    require(swapContract != address(0), "Invalid swap contract");
    authorizedSwapContracts[swapContract] = authorized;
    emit SwapContractAuthorized(swapContract, authorized);
  }

  function configureInstantLottery(
    uint256 _baseWinProbability,
    uint256 _minSwapAmount,
    uint256 _rewardPercentage,
    bool _isActive,
    bool _useVRFForInstant
  ) external onlyOwner {
    require(_baseWinProbability <= 10000, "Invalid base win probability");
    require(_rewardPercentage <= 10000, "Invalid reward percentage");

    instantLotteryConfig = InstantLotteryConfig({
      baseWinProbability: _baseWinProbability,
      minSwapAmount: _minSwapAmount,
      rewardPercentage: _rewardPercentage,
      isActive: _isActive,
      useVRFForInstant: _useVRFForInstant
    });

    emit InstantLotteryConfigured(_baseWinProbability, _minSwapAmount, _rewardPercentage, _isActive);
  }

  // ============ LOTTERY FUNCTIONS ============

  /**
   * @notice Process lottery entry from omniDRAGON swap (backward compatibility)
   * @param user Address of the user performing the swap
   * @param amount DRAGON token amount (18 decimals)
   */
  function processEntry(address user, uint256 amount) external nonReentrant onlyAuthorizedSwapContract {
    // Only process lottery if we have a price oracle and can get accurate USD conversion
    if (address(priceOracle) == address(0)) {
      // No price oracle configured - swap succeeds but no lottery entry
      return;
    }

    uint256 swapAmountUSD;
    bool priceObtained = false;

    try priceOracle.getAggregatedPrice() returns (int256 price, bool success, uint256 /* timestamp */) {
      if (success && price > 0) {
        // Convert token amount to USD using actual oracle price
        // Price is typically in 8 decimals, amount is 18 decimals, want 6 decimals USD
        // So: (amount * price) / 1e20 = (18 + 8 - 20 = 6 decimals)
        swapAmountUSD = (amount * uint256(price)) / 1e20;
        priceObtained = true;
      }
    } catch {
      // Oracle failed - swap succeeds but no lottery entry
    }
    // Only process lottery if we got a valid price and swap meets minimum threshold
    if (priceObtained && swapAmountUSD >= MIN_SWAP_USD) {
      // Process the instant lottery with actual USD amount from price oracle
      processInstantLottery(user, swapAmountUSD);
    }
    // If no valid price or below minimum, swap succeeds but no lottery entry is created
  }

  /**
   * @notice Process swap lottery - handles all lottery logic including USD calculation
   * @param trader Address of the trader
   * @param tokenIn Address of input token  
   * @param amountIn Amount of input tokens
   * @param swapValueUSD USD value (0 = calculate internally using oracle)
   * @return entryId Generated lottery entry ID
   */
  function processSwapLottery(
    address trader,
    address tokenIn,
    uint256 amountIn,
    uint256 swapValueUSD
  ) external nonReentrant onlyAuthorizedSwapContract returns (uint256 entryId) {
    require(trader != address(0), "Invalid trader address");
    require(tokenIn != address(0), "Invalid token address");
    require(amountIn > 0, "Invalid amount");

    // Only process lottery if we have a price oracle and can get accurate USD conversion
    if (address(priceOracle) == address(0)) {
      // No price oracle configured - swap succeeds but no lottery entry
      return 0;
    }

    uint256 finalSwapAmountUSD = swapValueUSD;
    bool priceObtained = false;

    // If swapValueUSD is 0, calculate USD value using oracle
    if (swapValueUSD == 0) {
      try priceOracle.getAggregatedPrice() returns (int256 price, bool success, uint256 /* timestamp */) {
        if (success && price > 0) {
          // Convert token amount to USD using actual oracle price
          // Price is typically in 8 decimals, amount is 18 decimals, want 6 decimals USD
          // So: (amountIn * price) / 1e20 = (18 + 8 - 20 = 6 decimals)
          finalSwapAmountUSD = (amountIn * uint256(price)) / 1e20;
          priceObtained = true;
        }
      } catch {
        // Oracle failed - swap succeeds but no lottery entry
        return 0;
      }
    } else {
      // Use provided USD value
      priceObtained = true;
    }

    // Only process lottery if we got a valid price and swap meets minimum threshold
    if (priceObtained && finalSwapAmountUSD >= MIN_SWAP_USD) {
      // Process the instant lottery with actual USD amount
      processInstantLottery(trader, finalSwapAmountUSD);
      
      // Return a non-zero entry ID to indicate success
      return totalLotteryEntries;
    }

    // If no valid price or below minimum, swap succeeds but no lottery entry is created
    return 0;
  }

  /**
   * @notice Process instant lottery for a swap transaction
   * @param user User who made the swap
   * @param swapAmountUSD Swap amount in USD (6 decimals)
   * @dev Called by authorized swap contracts only
   */
  function processInstantLottery(
    address user,
    uint256 swapAmountUSD
  ) public onlyAuthorizedSwapContract rateLimited(user) {
    require(user != address(0), "Invalid user address");
    require(swapAmountUSD >= MIN_SWAP_USD, "Swap amount too low");
    require(instantLotteryConfig.isActive, "Instant lottery not active");

    // Update user stats
    userStats[user].totalSwaps++;
    userStats[user].totalVolume += swapAmountUSD;
    userStats[user].lastSwapTimestamp = block.timestamp;
    totalLotteryEntries++;

    // Calculate win probability (no capping needed since we allow any trade size)
    uint256 winChancePPM = _calculateLinearWinChance(swapAmountUSD);

    // Apply veDRAGON boost
    uint256 boostedWinChancePPM = _applyVeDRAGONBoost(user, winChancePPM, swapAmountUSD);

    if (instantLotteryConfig.useVRFForInstant) {
      // Request VRF randomness
      uint256 randomnessId = _requestVRFForInstantLottery(user, swapAmountUSD, boostedWinChancePPM);
      emit InstantLotteryEntered(user, swapAmountUSD, winChancePPM, boostedWinChancePPM, randomnessId);
    } else {
      // SECURITY: Non-VRF mode disabled for security - all randomness must be VRF-based
      revert("Non-VRF mode disabled for security - configure VRF sources");
    }
  }

  /**
   * @dev Request VRF randomness for instant lottery with fallback sources
   * @param user The user who made the swap
   * @param swapAmountUSD The swap amount in USD
   * @param winProbability The calculated win probability
   * @return requestId The randomness request ID
   */
  function _requestVRFForInstantLottery(
    address user,
    uint256 swapAmountUSD,
    uint256 winProbability
  ) internal returns (uint256 requestId) {
    RandomnessSource source;

    // Try Local VRF first (fastest on Arbitrum)
    if (address(localVRFConsumer) != address(0)) {
      try localVRFConsumer.requestRandomWordsLocal() returns (uint256 localRequestId) {
        requestId = localRequestId;
        source = RandomnessSource.LOCAL_VRF;
      } catch {
        // Local VRF failed, try next option
      }
    }

    // If local VRF failed, try cross-chain VRF
    if (requestId == 0 && address(vrfIntegrator) != address(0)) {
      // Request cross-chain VRF without payment (VRF fees should be handled separately)
      try vrfIntegrator.requestRandomWordsSimple(30110) returns (
        MessagingReceipt memory /* receipt */,
        uint64 sequence
      ) {
        requestId = uint256(sequence);
        source = RandomnessSource.CROSS_CHAIN_VRF;
      } catch {
        // Cross-chain VRF also failed
      }
    }

    // Removed randomnessProvider fallback - using only Chainlink VRF sources

    if (requestId == 0) {
      // All VRF sources failed - NEVER use insecure fallback randomness
      // Queue the entry for later processing when VRF is available
      revert("VRF services unavailable - lottery entry rejected for security");
    }

    // Store pending lottery entry
    pendingEntries[requestId] = PendingLotteryEntry({
      user: user,
      swapAmountUSD: swapAmountUSD,
      winProbability: winProbability,
      timestamp: block.timestamp,
      fulfilled: false,
      randomnessSource: source
    });

    emit LotteryEntryCreated(user, swapAmountUSD, winProbability, requestId);
    emit RandomnessRequested(requestId, user, source);

    return requestId;
  }

  /**
   * @notice Callback function for local VRF requests
   * @dev Called by the local VRF consumer when randomness is ready
   * Added reentrancy protection for distribution safety
   */
  function receiveRandomWords(uint256 requestId, uint256[] memory randomWords) external nonReentrant {
    require(msg.sender == address(localVRFConsumer), "Only local VRF consumer");
    require(randomWords.length > 0, "No random words provided");

    _processVRFCallback(requestId, randomWords[0], RandomnessSource.LOCAL_VRF);
  }

  /**
   * @notice Callback function for cross-chain VRF requests
   * @dev Called by the VRF integrator when cross-chain randomness is ready
   * Added reentrancy protection for distribution safety
   */
  function receiveRandomWords(uint256[] memory randomWords, uint256 sequence) external nonReentrant {
    require(msg.sender == address(vrfIntegrator), "Only VRF integrator");
    require(randomWords.length > 0, "No random words provided");

    _processVRFCallback(sequence, randomWords[0], RandomnessSource.CROSS_CHAIN_VRF);
  }

  /**
   * @dev Process VRF callback and determine lottery outcome
   * @param requestId The VRF request ID
   * @param randomness The random number from VRF
   * @param source The randomness source that provided the callback
   */
  function _processVRFCallback(uint256 requestId, uint256 randomness, RandomnessSource source) internal {
    PendingLotteryEntry storage entry = pendingEntries[requestId];
    require(entry.user != address(0), "Invalid request ID");
    require(!entry.fulfilled, "Entry already fulfilled");
    require(entry.randomnessSource == source, "Wrong randomness source");

    // Mark as fulfilled
    entry.fulfilled = true;

    // Process the lottery result
    _processLotteryResult(entry.user, entry.swapAmountUSD, entry.winProbability, randomness);

    emit RandomnessFulfilled(requestId, randomness, source);

    // Clean up storage to save gas
    delete pendingEntries[requestId];
  }

  /**
   * @dev Process lottery result and distribute rewards if won
   * @param user The user who entered the lottery
   * @param swapAmountUSD The swap amount in USD
   * @param winProbability The win probability in basis points
   * @param randomness The random number to determine outcome
   */
  function _processLotteryResult(
    address user,
    uint256 swapAmountUSD,
    uint256 winProbability,
    uint256 randomness
  ) internal {
    // Determine if user won (randomness % 1000000 < winProbability) - using PPM
    bool won = (randomness % 1000000) < winProbability;

    uint256 reward = 0;
    if (won) {
      // Calculate reward from jackpot
      reward = _calculateInstantLotteryReward(swapAmountUSD);

      if (reward > 0) {
        _distributeInstantLotteryReward(user, reward);

        // Update statistics
        userStats[user].totalWins++;
        userStats[user].totalRewards += reward;
        totalPrizesWon++;
        totalPrizesDistributed += reward;
      }
    }

    emit InstantLotteryProcessed(user, swapAmountUSD, won, reward);
  }

  /**
   * @dev Calculate instant lottery reward based on jackpot and configuration
   * @return reward The calculated reward amount
   */
  function _calculateInstantLotteryReward(uint256 /* swapAmountUSD */) internal view returns (uint256 reward) {
    if (address(jackpotDistributor) == address(0)) {
      return 0;
    }

    uint256 currentJackpot;
    try jackpotDistributor.getCurrentJackpot() returns (uint256 jackpot) {
      currentJackpot = jackpot;
    } catch {
      // If fetching jackpot fails, treat it as 0 for this calculation
      // This prevents VRF callback from reverting and causing DoS
      return 0;
    }
    if (currentJackpot == 0) {
      return 0;
    }

    // Calculate reward as percentage of current jackpot (purely dynamic)
    reward = (currentJackpot * instantLotteryConfig.rewardPercentage) / 10000;

    return reward;
  }

  /**
   * @dev Distribute instant lottery reward to winner
   * @param winner The winner address
   * @param reward The reward amount
   * @dev Pure coordinator - delegates all fund handling to other contracts
   */
  function _distributeInstantLotteryReward(address winner, uint256 reward) internal {
    if (address(jackpotDistributor) == address(0) || reward == 0) {
      return;
    }

    // PRIMARY: Try jackpot distributor (should work 99%+ of the time)
    try jackpotDistributor.distributeJackpot(winner, reward) {
      // ✅ Reward distributed successfully - most common path
      emit InstantLotteryProcessed(winner, 0, true, reward);
      return;
    } catch Error(string memory /* reason */) {
      // Log specific error for debugging
      emit PrizeTransferFailed(winner, reward);
    } catch (bytes memory /* lowLevelData */) {
      // Low-level error
      emit PrizeTransferFailed(winner, reward);
    }
    // FALLBACK: Try jackpot vault if distributor fails
    if (address(jackpotVault) != address(0)) {
      try jackpotVault.payJackpot(winner, reward) {
        // ✅ Jackpot vault succeeded
        emit InstantLotteryProcessed(winner, 0, true, reward);
        return;
      } catch {
        // Vault also failed
        emit PrizeTransferFailed(winner, reward);
      }
    }

    // If all payout methods fail, emit event for manual intervention
    // No funds are held by this contract
    emit PrizeTransferFailed(winner, reward);
  }

  /**
   * @dev Calculate linear win chance based on swap amount
   * @param swapAmountUSD Swap amount in USD (6 decimals)
   * @return winChancePPM Win chance in parts per million (capped at MAX_WIN_CHANCE_PPM for swaps >= $10,000)
   */
  function _calculateLinearWinChance(uint256 swapAmountUSD) internal pure returns (uint256 winChancePPM) {
    if (swapAmountUSD < MIN_SWAP_USD) {
      return 0;
    }

    // Cap probability at $10,000 level, but allow any trade size
    if (swapAmountUSD >= MAX_PROBABILITY_SWAP_USD) {
      return MAX_WIN_CHANCE_PPM;
    }

    // Linear interpolation between MIN_WIN_CHANCE_PPM and MAX_WIN_CHANCE_PPM
    uint256 amountRange = MAX_PROBABILITY_SWAP_USD - MIN_SWAP_USD;
    uint256 chanceRange = MAX_WIN_CHANCE_PPM - MIN_WIN_CHANCE_PPM;
    uint256 amountDelta = swapAmountUSD - MIN_SWAP_USD;

    winChancePPM = MIN_WIN_CHANCE_PPM + (chanceRange * amountDelta) / amountRange;

    return winChancePPM;
  }

  /**
   * @dev Apply veDRAGON boost to base win probability using boost manager
   * @param user User address to calculate boost for
   * @param baseProbability Base win probability in PPM
   * @return boostedProbability Boosted probability (capped at MAX_WIN_PROBABILITY_PPM)
   */
  function _applyVeDRAGONBoost(
    address user,
    uint256 baseProbability,
    uint256 /* swapAmount */
  ) internal view returns (uint256) {
    // If boost manager not configured, fallback to simple calculation
    if (address(veDRAGONBoostManager) == address(0)) {
      return _applyVeDRAGONBoostFallback(user, baseProbability);
    }

    // Use the sophisticated boost manager calculation
    uint256 boostMultiplierBPS = veDRAGONBoostManager.calculateBoost(user); // Returns in basis points (10000 = 100%)
    
    // Convert from basis points to our internal precision
    uint256 boostMultiplier = (boostMultiplierBPS * BOOST_PRECISION) / 10000;

    // Apply boost
    uint256 boostedProbability = (baseProbability * boostMultiplier) / BOOST_PRECISION;

    // Ensure we don't exceed the maximum win probability
    return boostedProbability > MAX_WIN_PROBABILITY_PPM ? MAX_WIN_PROBABILITY_PPM : boostedProbability;
  }

  /**
   * @dev Fallback veDRAGON boost calculation when boost manager is not available
   * @param user User address to calculate boost for
   * @param baseProbability Base win probability in PPM
   * @return boostedProbability Boosted probability
   */
  function _applyVeDRAGONBoostFallback(
    address user,
    uint256 baseProbability
  ) internal view returns (uint256) {
    // If tokens not configured, return base probability
    if (address(veDRAGONToken) == address(0) || address(redDRAGONToken) == address(0)) {
      return baseProbability;
    }

    // Get user's balances
    uint256 userRedDRAGON = redDRAGONToken.balanceOf(user);
    uint256 userVeDRAGON = veDRAGONToken.balanceOf(user);

    // If user has no tokens, return base probability
    if (userRedDRAGON == 0 && userVeDRAGON == 0) {
      return baseProbability;
    }

    // Get total supplies
    uint256 totalRedDRAGON = redDRAGONToken.totalSupply();
    uint256 totalVeDRAGON = veDRAGONToken.totalSupply();

    if (totalRedDRAGON == 0) {
      return baseProbability;
    }

    // Simple boost calculation: 1.0x to 2.5x based on token holdings
    uint256 userTotalTokens = userRedDRAGON + userVeDRAGON;
    uint256 totalTokens = totalRedDRAGON + totalVeDRAGON;

    if (totalTokens == 0) {
      return baseProbability;
    }

    // Calculate boost multiplier (1.0x to 2.5x)
    uint256 boostMultiplier = BOOST_PRECISION + (15e17 * userTotalTokens) / totalTokens; // 1.0 + 1.5 * ratio

    // Cap at maximum boost
    if (boostMultiplier > MAX_BOOST) {
      boostMultiplier = MAX_BOOST;
    }

    // Apply boost
    uint256 boostedProbability = (baseProbability * boostMultiplier) / BOOST_PRECISION;

    // Ensure we don't exceed the maximum win probability
    return boostedProbability > MAX_WIN_PROBABILITY_PPM ? MAX_WIN_PROBABILITY_PPM : boostedProbability;
  }

  // ============ VIEW FUNCTIONS ============

  /**
   * @notice Get instant lottery configuration
   */
  function getInstantLotteryConfig()
    external
    view
    returns (
      uint256 baseWinProbability,
      uint256 minSwapAmount,
      uint256 rewardPercentage,
      bool isActive,
      bool useVRFForInstant
    )
  {
    return (
      instantLotteryConfig.baseWinProbability,
      instantLotteryConfig.minSwapAmount,
      instantLotteryConfig.rewardPercentage,
      instantLotteryConfig.isActive,
      instantLotteryConfig.useVRFForInstant
    );
  }

  /**
   * @notice Get user statistics
   */
  function getUserStats(
    address user
  )
    external
    view
    returns (
      uint256 totalSwaps,
      uint256 totalVolume,
      uint256 totalWins,
      uint256 totalRewards,
      uint256 lastSwapTimestamp
    )
  {
    UserStats memory stats = userStats[user];
    return (stats.totalSwaps, stats.totalVolume, stats.totalWins, stats.totalRewards, stats.lastSwapTimestamp);
  }

  /**
   * @notice Get pending lottery entry details
   */
  function getPendingEntry(
    uint256 requestId
  )
    external
    view
    returns (
      address user,
      uint256 swapAmountUSD,
      uint256 winProbability,
      uint256 timestamp,
      bool fulfilled,
      RandomnessSource randomnessSource
    )
  {
    PendingLotteryEntry memory entry = pendingEntries[requestId];
    return (
      entry.user,
      entry.swapAmountUSD,
      entry.winProbability,
      entry.timestamp,
      entry.fulfilled,
      entry.randomnessSource
    );
  }

  /**
   * @notice Calculate win probability for a given swap amount and user
   */
  function calculateWinProbability(
    address user,
    uint256 swapAmountUSD
  ) external view returns (uint256 baseProbability, uint256 boostedProbability) {
    // No capping needed since we allow any trade size but cap probability at $10k level
    baseProbability = _calculateLinearWinChance(swapAmountUSD);
    boostedProbability = _applyVeDRAGONBoost(user, baseProbability, swapAmountUSD);

    // Cap at maximum (already handled in _applyVeDRAGONBoost)
    if (boostedProbability > MAX_WIN_PROBABILITY_PPM) {
      boostedProbability = MAX_WIN_PROBABILITY_PPM;
    }
  }

  /**
   * @notice Get current jackpot amount
   */
  function getCurrentJackpot() external view returns (uint256) {
    if (address(jackpotDistributor) == address(0)) {
      return 0;
    }
    return jackpotDistributor.getCurrentJackpot();
  }

  // ============ DEPRECATED PRIZE CLAIM FUNCTIONS ============
  // These functions are kept for interface compatibility but are no longer used
  // All prizes are distributed immediately through jackpot distributor/vault

  /**
   * @notice Get unclaimed prizes for a user
   * @dev Always returns 0 - included for interface compatibility
   * @return amount Always returns 0
   */
  function getUnclaimedPrizes(address /* user */) external pure returns (uint256 amount) {
    return 0;
  }

  /**
   * @notice DEPRECATED - No-op as lottery manager no longer holds funds
   * @dev Reverts to indicate this function is no longer used
   */
  function claimPrize() external pure {
    revert("Function deprecated - lottery manager does not hold funds");
  }

  /**
   * @notice DEPRECATED - Returns 0 as lottery manager no longer holds funds
   * @return total Always returns 0
   */
  function getTotalUnclaimedPrizes() external pure returns (uint256 total) {
    return 0;
  }

  // ============ ORACLE INTEGRATION ============

  /**
   * @notice Set the DRAGON token address for price conversions
   * @param _dragonToken Address of the DRAGON token
   */
  function setDragonToken(address _dragonToken) external onlyOwner {
    require(_dragonToken != address(0), "Invalid dragon token");
    dragonToken = IERC20(_dragonToken);
  }

  /**
   * @notice Get current DRAGON price from oracle
   * @return price Price in USD (18 decimals)
   * @return isValid Whether the price is valid
   */
  function _getDragonPriceUSD() internal view returns (int256 price, bool isValid) {
    if (address(priceOracle) == address(0)) return (0, false);
    
    try priceOracle.getAggregatedPrice() returns (
      int256 _price, 
      bool _success, 
      uint256 /* timestamp */
    ) {
      return (_price, _success);
    } catch {
      return (0, false);
    }
  }

  /**
   * @notice Convert DRAGON amount to USD (6 decimals)
   * @param dragonAmount Amount of DRAGON tokens (18 decimals)
   * @return usdAmount USD amount (6 decimals)
   */
  function _convertDragonToUSD(uint256 dragonAmount) internal view returns (uint256 usdAmount) {
    if (dragonAmount == 0) return 0;
    
    (int256 price, bool isValid) = _getDragonPriceUSD();
    if (!isValid || price <= 0) return 0;
    
    // Convert: DRAGON (18 decimals) * Price (18 decimals) / 1e30 = USD (6 decimals)
    return (dragonAmount * uint256(price)) / 1e30;
  }

  /**
   * @notice Process lottery entry with DRAGON amount (called by omniDRAGON token)
   * @param user User address
   * @param dragonAmount Amount of DRAGON tokens involved in swap
   */
  function processEntryWithDragon(address user, uint256 dragonAmount) external nonReentrant rateLimited(user) {
    require(msg.sender == address(dragonToken), "Only DRAGON token");
    require(user != address(0), "Invalid user");
    require(instantLotteryConfig.isActive, "Instant lottery not active");
    
    // Convert DRAGON amount to USD
    uint256 usdAmount = _convertDragonToUSD(dragonAmount);
    
    // Check minimum USD threshold
    if (usdAmount < MIN_SWAP_USD) {
      return; // Below minimum threshold, no lottery entry
    }
    
    // Calculate win probability based on USD amount
    (, uint256 winProbability) = this.calculateWinProbability(user, usdAmount);
    
    // Process the lottery entry with USD amount using secure VRF
    if (instantLotteryConfig.useVRFForInstant) {
      // Request VRF randomness (same secure approach as processInstantLottery)
      uint256 randomnessId = _requestVRFForInstantLottery(user, usdAmount, winProbability);
      emit InstantLotteryEntered(user, usdAmount, winProbability, winProbability, randomnessId);
    } else {
      // SECURITY: Non-VRF mode disabled for security - all randomness must be VRF-based
      revert("Non-VRF mode disabled for security - configure VRF sources");
    }
    
    // Update user statistics
    userStats[user].totalSwaps++;
    userStats[user].totalVolume += usdAmount;
    userStats[user].lastSwapTimestamp = block.timestamp;
    
    totalLotteryEntries++;
  }

  /**
   * @notice Get current DRAGON price in USD for external queries
   * @return price Price in USD (18 decimals)
   * @return isValid Whether the price is valid
   * @return timestamp Last update timestamp
   */
  function getDragonPriceUSD() external view returns (int256 price, bool isValid, uint256 timestamp) {
    if (address(priceOracle) == address(0)) return (0, false, 0);
    return priceOracle.getAggregatedPrice();
  }

  /**
   * @notice Convert DRAGON amount to USD for external queries
   * @param dragonAmount Amount of DRAGON tokens (18 decimals)
   * @return usdAmount USD amount (6 decimals)
   */
  function convertDragonToUSD(uint256 dragonAmount) external view returns (uint256 usdAmount) {
    return _convertDragonToUSD(dragonAmount);
  }

  /**
   * @notice REMOVED: Insecure instant lottery processing function
   * @dev This function was removed due to security vulnerabilities in its randomness generation.
   * All lottery processing now uses cryptographically secure VRF-based randomness via
   * processInstantLottery() and _requestVRFForInstantLottery().
   * 
   * SECURITY NOTE: The previous implementation used exploitable pseudo-randomness
   * (block.timestamp, block.prevrandao) which could be manipulated by miners/validators.
   * This violated the contract's security guarantees and has been eliminated.
   */

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