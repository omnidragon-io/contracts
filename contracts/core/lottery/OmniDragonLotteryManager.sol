// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IChainlinkVRFIntegratorV2_5} from "../../interfaces/vrf/IChainlinkVRFIntegratorV2_5.sol";
import {IOmniDragonVRFConsumerV2_5} from "../../interfaces/vrf/IOmniDragonVRFConsumerV2_5.sol";
import {DragonJackpotVault} from "./DragonJackpotVault.sol";

// Interface for local VRF callbacks
interface IVRFCallbackReceiver {
  function receiveRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}
import {MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IOmniDragonOracle} from "../../interfaces/oracles/IOmniDragonOracle.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IveDRAGON {
  function getVotingPower(address user) external view returns (uint256);
}
import {IveDRAGONBoostManager} from "../../interfaces/governance/voting/IveDRAGONBoostManager.sol";

interface IPriceOracleLike {
  function getLatestPrice() external view returns (int256 price, uint256 timestamp); // TOKEN/USD 1e18
}

// ============ INTERFACES ============

interface IveDRAGONToken {
  function lockedEnd(address user) external view returns (uint256);
  function balanceOf(address user) external view returns (uint256);
  function totalSupply() external view returns (uint256);
  function locked(address user) external view returns (uint256 amount, uint256 unlockTime);
}

interface IredDRAGON {
  function convertToAssets(uint256 shares) external view returns (uint256 assets);
  function balanceOf(address account) external view returns (uint256);
  function asset() external view returns (address);
}

interface IUniswapV2Pair {
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
  function totalSupply() external view returns (uint256);
  function token0() external view returns (address);
  function token1() external view returns (address);
}



/**
 * @title OmniDragonLotteryManager
 * @author 0xakita.eth
 * @dev Enhanced lottery manager with efficient oracle price updates and improved VRF integration
 *
 * Key improvements:
 * - Calls updatePrice() on primary oracle before price queries for fresh data
 * - Better VRF integration with ChainlinkVRFIntegratorV2_5
 * - Gas-optimized lottery processing functions
 * - Enhanced error handling and fallback mechanisms
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract OmniDragonLotteryManager is Ownable, ReentrancyGuard, Pausable, IVRFCallbackReceiver {
  using SafeERC20 for IERC20;
  using Address for address payable;

  // ============ CONSTANTS ============

  uint256 public constant MAX_BOOST_BPS = 25000; // 2.5x boost maximum
  uint256 public constant MAX_WIN_PROBABILITY_PPM = 100000; // 10% maximum win probability (100,000 PPM)

  // Instant lottery configuration (USD-based with 6 decimals)
  uint256 public constant MIN_SWAP_USD = 10e6; // $10 USD minimum
  uint256 public constant MAX_PROBABILITY_SWAP_USD = 10000e6; // $10,000 USD for max probability
  uint256 public constant MIN_WIN_CHANCE_PPM = 40; // 0.004% (40 parts per million) at $10
  uint256 public constant MAX_WIN_CHANCE_PPM = 40000; // 4% (40,000 parts per million) at $10,000+

  // veDRAGON boost configuration
  uint256 public constant BOOST_PRECISION = 1e18;

  // Oracle price updates happen on every swap for maximum freshness
  uint256 public maxPriceUpdateGas = 500000; // Max gas for updatePrice call (adjustable)

  // ============ ENUMS ============

  enum RandomnessSource {
    LOCAL_VRF, // Local: Direct Chainlink VRF
    CROSS_CHAIN_VRF // Cross-chain: Chainlink VRF via LayerZero
  }

  // ============ STRUCTS ============

  struct InstantLotteryConfig {
    uint256 minSwapAmount; // Minimum swap amount to qualify (in USD, scaled by 1e6)
    uint256 rewardPercentage; // Percentage of jackpot as reward (in basis points)
    bool isActive;
    bool useVRFForInstant; // Whether to use VRF for instant lotteries (recommended)
    bool enablePriceUpdates; // Whether to call updatePrice() on oracle before lottery processing
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

  // ============ STATE VARIABLES ============

  // Core dependencies
  IERC20 public veDRAGONToken;
  IERC20 public redDRAGONToken;
  IveDRAGONBoostManager public veDRAGONBoostManager;

  // VRF integrations
  IChainlinkVRFIntegratorV2_5 public vrfIntegrator;
  IOmniDragonVRFConsumerV2_5 public localVRFConsumer;
  DragonJackpotVault public jackpotVault;

  // Market infrastructure integration
  IOmniDragonOracle public primaryOracle; // Used on Sonic chain (146)
  address public priceOracle; // Used on other chains (OmniDragonPriceOracle with LayerZero Read)
  uint256 public immutable CHAIN_ID;
  uint256 public constant SONIC_CHAIN_ID = 146; // Sonic blockchain chain ID

  // Oracle optimization
  uint256 public lastPriceUpdate;

  // Rate limiting removed

  // Access control
  mapping(address => bool) public authorizedSwapContracts;

  // Lottery state
  mapping(bytes32 => PendingLotteryEntry) public pendingEntries;
  mapping(address => UserStats) public userStats;

  // Statistics
  uint256 public totalLotteryEntries;
  uint256 public totalPrizesWon;
  uint256 public totalPrizesDistributed;

  InstantLotteryConfig public instantLotteryConfig;

  // LayerZero configuration
  uint32 public targetEid = 30110; // Default to Arbitrum mainnet, configurable
  
  // Token price oracle mapping
  mapping(address => address) public tokenUsdOracle;

  // ============ EVENTS ============

  event InstantLotteryProcessed(address indexed user, uint256 swapAmount, bool won, uint256 rewardInJackpotUnits);
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
    uint256 minSwapAmount,
    uint256 rewardPercentage,
    bool isActive,
    bool enablePriceUpdates
  );
  event SwapContractAuthorized(address indexed swapContract, bool authorized);
  event LotteryManagerInitialized(address jackpotVault, address veDRAGONToken);
  event PrimaryOracleUpdated(address indexed primaryOracle);
  event PriceOracleUpdated(address indexed priceOracle);
  event VRFFunded(address indexed funder, uint256 amount);

  event RedDRAGONTokenUpdated(address indexed redDRAGONToken);
  event OraclePriceUpdateAttempted(address indexed oracle, bool success, uint256 gasUsed);
  event TokenUsdOracleSet(address indexed token, address indexed oracle);

  event VeDRAGONTokenUpdated(address indexed oldToken, address indexed newToken);
  event VeDRAGONBoostManagerUpdated(address indexed oldManager, address indexed newManager);
  event FeeMRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
  event ExcessRefunded(address indexed recipient, uint256 amount);

  // Debugging and observability events
  event SwapEntrySkipped(
    string reason,
    uint256 finalSwapAmountUSD,
    bool priceObtained,
    uint256 vrfFeeRequired,
    uint256 managerNativeBalance
  );
  event VRFRequestFailed(uint256 requiredFee, uint256 availableBalance);

  // ============ CONSTRUCTOR ============

  constructor(
    address payable _jackpotVault,
    address _veDRAGONToken,
    address payable _oracleAddress,
    uint256 _chainId
  ) Ownable(msg.sender) {
    require(_jackpotVault != address(0), "Invalid jackpot vault");
    require(_veDRAGONToken != address(0), "Invalid veDRAGON token");
    require(_oracleAddress != address(0), "Invalid oracle address");

    jackpotVault = DragonJackpotVault(_jackpotVault);
    veDRAGONToken = IERC20(_veDRAGONToken);

    CHAIN_ID = _chainId;

    // Smart oracle assignment based on chain
    if (_chainId == SONIC_CHAIN_ID) {
      // On Sonic: Use PrimaryOracle directly (source of truth)
      primaryOracle = IOmniDragonOracle(_oracleAddress);
      priceOracle = address(0); // Not needed on Sonic
    } else {
      // On other chains: Use PriceOracle with LayerZero Read
      primaryOracle = IOmniDragonOracle(address(0)); // Not available on other chains
      priceOracle = _oracleAddress; // OmniDragonPriceOracle address
    }

    // Initialize instant lottery config with enhanced settings
    instantLotteryConfig = InstantLotteryConfig({
      minSwapAmount: MIN_SWAP_USD,
      rewardPercentage: 6900, // 69% of jackpot
      isActive: true,
      useVRFForInstant: true,
      enablePriceUpdates: true // Enable automatic price updates
    });

    emit LotteryManagerInitialized(_jackpotVault, _veDRAGONToken);
  }

  // ============ MODIFIERS ============

  modifier onlyAuthorizedSwapContract() {
    require(authorizedSwapContracts[msg.sender], "Unauthorized swap contract");
    _;
  }

  // Rate limiting removed to prevent reverts

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

  function setJackpotVault(address payable _jackpotVault) external onlyOwner {
    require(_jackpotVault != address(0), "Invalid jackpot vault");
    jackpotVault = DragonJackpotVault(_jackpotVault);
  }

  function setPrimaryOracle(address payable _primaryOracle) external onlyOwner {
    require(_primaryOracle != address(0), "Invalid oracle address");
    require(CHAIN_ID == SONIC_CHAIN_ID, "Primary oracle only available on Sonic");
    primaryOracle = IOmniDragonOracle(_primaryOracle);
    emit PrimaryOracleUpdated(_primaryOracle);
  }

  function setPriceOracle(address _priceOracle) external onlyOwner {
    require(_priceOracle != address(0), "Invalid price oracle address");
    require(CHAIN_ID != SONIC_CHAIN_ID, "Price oracle not needed on Sonic");
    priceOracle = _priceOracle;
    emit PriceOracleUpdated(_priceOracle);
  }

  function setRedDRAGONToken(address _redDRAGONToken) external onlyOwner {
    require(_redDRAGONToken != address(0), "Invalid redDRAGON token");
    redDRAGONToken = IERC20(_redDRAGONToken);
    emit RedDRAGONTokenUpdated(_redDRAGONToken);
  }

  function setVeDRAGONBoostManager(address _veDRAGONBoostManager) external onlyOwner {
    require(_veDRAGONBoostManager != address(0), "Invalid veDRAGON boost manager");
    address oldManager = address(veDRAGONBoostManager);
    veDRAGONBoostManager = IveDRAGONBoostManager(_veDRAGONBoostManager);
    emit VeDRAGONBoostManagerUpdated(oldManager, _veDRAGONBoostManager);
  }

  function setAuthorizedSwapContract(address swapContract, bool authorized) external onlyOwner {
    require(swapContract != address(0), "Invalid swap contract");
    authorizedSwapContracts[swapContract] = authorized;
    emit SwapContractAuthorized(swapContract, authorized);
  }

  function configureInstantLottery(
    uint256 _minSwapAmount,
    uint256 _rewardPercentage,
    bool _isActive,
    bool _useVRFForInstant,
    bool _enablePriceUpdates
  ) external onlyOwner {
    require(_rewardPercentage <= 10000, "Invalid reward percentage");

    instantLotteryConfig = InstantLotteryConfig({
      minSwapAmount: _minSwapAmount,
      rewardPercentage: _rewardPercentage,
      isActive: _isActive,
      useVRFForInstant: _useVRFForInstant,
      enablePriceUpdates: _enablePriceUpdates
    });

    emit InstantLotteryConfigured(_minSwapAmount, _rewardPercentage, _isActive, _enablePriceUpdates);
  }

  // ============ ENHANCED ORACLE INTEGRATION ============

  /**
   * @notice Always update oracle price on every swap
   * @dev Calls updatePrice() on every swap for freshest data
   * @return wasUpdated Whether the price was actually updated
   */
  function _updateOraclePriceEverySwap() internal returns (bool wasUpdated) {
    // Allow disabling direct oracle updates via config to prevent swap path reverts
    if (!instantLotteryConfig.enablePriceUpdates) {
      return true;
    }
    // On Sonic: Update primary oracle directly
    if (CHAIN_ID == SONIC_CHAIN_ID && address(primaryOracle) != address(0)) {
      uint256 gasStart = gasleft();
      
      // Do not decode any return value to avoid ABI mismatch issues
      try primaryOracle.updatePrice{gas: maxPriceUpdateGas}() {
        lastPriceUpdate = block.timestamp;
        uint256 gasUsed = gasStart - gasleft();
        emit OraclePriceUpdateAttempted(address(primaryOracle), true, gasUsed);
        return true;
      } catch {
        uint256 gasUsed = gasStart - gasleft();
        emit OraclePriceUpdateAttempted(address(primaryOracle), false, gasUsed);
        return false;
      }
    }
    
    // On other chains: Price oracle gets updates via LayerZero Read automatically
    // No direct updatePrice() call needed - price is fetched when requested
    return true;
  }



  // ============ LOTTERY FUNCTIONS ============
  /**
   * @notice Main swap lottery processing with automatic price updates and VRF fee handling
   * @dev Simplified single lottery type with unified boost calculation via veDRAGONBoostManager
   */
  function processSwapLottery(
    address trader,
    address tokenIn,
    uint256 amountIn,
    uint256 swapValueUSD
  ) external payable nonReentrant onlyAuthorizedSwapContract whenNotPaused returns (uint256 entryId) {
    require(trader != address(0), "Invalid trader address");
    require(tokenIn != address(0), "Invalid token address");
    require(amountIn > 0, "Invalid amount");

    // Step 1: Always update oracle price on every swap
    bool oracleUpdateSuccess = _updateOraclePriceEverySwap();
    
    // FIX 3: Check oracle update result
    if (instantLotteryConfig.enablePriceUpdates && !oracleUpdateSuccess) {
      emit SwapEntrySkipped("oracle_update_failed", 0, false, 0, address(this).balance);
      return 0;
    }

    uint256 finalSwapAmountUSD = swapValueUSD;
    bool priceObtained = false;

    // Step 2: Calculate USD value using fresh oracle data
    if (swapValueUSD == 0) {
      // Try token-specific oracle first
      if (tokenUsdOracle[tokenIn] != address(0)) {
        finalSwapAmountUSD = _amountToUsd1e6(tokenIn, amountIn);
        priceObtained = finalSwapAmountUSD > 0;
      }
      
      // Fallback to primary oracle if no token oracle configured
      if (!priceObtained && address(primaryOracle) != address(0)) {
        try primaryOracle.getLatestPrice() returns (int256 price, uint256 /* timestamp */) {
          if (price > 0) {
            // Get token decimals
            uint8 decimals = 18;
            try IERC20Metadata(tokenIn).decimals() returns (uint8 d) {
              decimals = d;
            } catch {}
            
            // Convert to 6-decimal USD: (amountIn * price 1e18) / (10^decimals * 1e12) = 1e6
            finalSwapAmountUSD = (amountIn * uint256(price)) / (10 ** decimals) / 1e12;
            priceObtained = true;
          }
        } catch {}
      }
      
      if (!priceObtained) {
        emit SwapEntrySkipped("no_usd_value_and_no_oracle", 0, false, 0, address(this).balance);
        return 0;
      }
    } else {
      priceObtained = true;
    }

    if (!(priceObtained && finalSwapAmountUSD >= instantLotteryConfig.minSwapAmount)) {
      emit SwapEntrySkipped("below_min_swap_amount", finalSwapAmountUSD, priceObtained, 0, address(this).balance);
      return 0;
    }

    require(instantLotteryConfig.isActive, "Instant lottery not active");
    require(
      address(localVRFConsumer) != address(0) || address(vrfIntegrator) != address(0),
      "No VRF source configured"
    );

    // Step 3: Enhanced VRF request with better fee handling
    uint256 baseProbability = _calculateLinearWinChance(finalSwapAmountUSD);
    uint256 boostedProbability = _applyVeDRAGONBoost(trader, baseProbability, finalSwapAmountUSD);
    uint256 requestId = _requestVRFEnhanced(trader, finalSwapAmountUSD, boostedProbability);
    
    if (requestId == 0) {
      return 0;
    }

    // Step 4: Update stats
    userStats[trader].totalSwaps++;
    userStats[trader].totalVolume += finalSwapAmountUSD;
    userStats[trader].lastSwapTimestamp = block.timestamp;
    totalLotteryEntries++;

    return requestId;
  }

  /**
   * @notice Enhanced VRF request with improved fee handling and fallback logic
   * @dev Better integration with ChainlinkVRFIntegratorV2_5
   */
  function _requestVRFEnhanced(
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
        // Local VRF failed, try cross-chain
      }
    }

    // Try cross-chain VRF with enhanced fee handling
    if (requestId == 0 && address(vrfIntegrator) != address(0)) {
      try vrfIntegrator.quoteFee() returns (MessagingFee memory fee) {
        // Check if contract has enough balance (includes msg.value)
        uint256 availableFee = address(this).balance;
        
        if (availableFee >= fee.nativeFee) {
          try vrfIntegrator.requestRandomWordsPayable{value: fee.nativeFee}(targetEid) returns (
        MessagingReceipt memory /* receipt */,
        uint64 sequence
      ) {
        requestId = uint256(sequence);
        source = RandomnessSource.CROSS_CHAIN_VRF;
      } catch {
            // VRF request failed
          }
        } else {
          emit VRFRequestFailed(fee.nativeFee, availableFee);
        }
      } catch {
        // Fee quote failed
      }
    }

    if (requestId == 0) {
      return 0;
    }

    // Store pending lottery entry with composite key
    pendingEntries[_getEntryKey(source, requestId)] = PendingLotteryEntry({
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
   * @notice Enhanced instant lottery processing with automatic price updates
   * @param user User who made the swap
   * @param swapAmountUSD Swap amount in USD (6 decimals)
   */
  function processInstantLottery(
    address user,
    uint256 swapAmountUSD
  ) public onlyAuthorizedSwapContract whenNotPaused {
    require(user != address(0), "Invalid user address");
    require(swapAmountUSD >= instantLotteryConfig.minSwapAmount, "Swap amount too low");
    require(instantLotteryConfig.isActive, "Instant lottery not active");

    // Calculate win probability
    uint256 winChancePPM = _calculateLinearWinChance(swapAmountUSD);
    uint256 boostedWinChancePPM = _applyVeDRAGONBoost(user, winChancePPM, swapAmountUSD);

    if (instantLotteryConfig.useVRFForInstant) {
      uint256 randomnessId = _requestVRFEnhanced(user, swapAmountUSD, boostedWinChancePPM);
      if (randomnessId == 0) {
        return;
      }
      
      // Only update stats after successful VRF request
      userStats[user].totalSwaps++;
      userStats[user].totalVolume += swapAmountUSD;
      userStats[user].lastSwapTimestamp = block.timestamp;
      totalLotteryEntries++;
      
      emit InstantLotteryEntered(user, swapAmountUSD, winChancePPM, boostedWinChancePPM, randomnessId);
    } else {
      revert("Non-VRF mode disabled for security - configure VRF sources");
    }
  }

  // ============ VRF CALLBACK FUNCTIONS ============

  /**
   * @notice Callback function for local VRF requests
   */
  function receiveRandomWords(uint256 requestId, uint256[] memory randomWords) external nonReentrant {
    require(msg.sender == address(localVRFConsumer), "Only local VRF consumer");
    require(randomWords.length > 0, "No random words provided");

    _processVRFCallback(requestId, randomWords[0], RandomnessSource.LOCAL_VRF);
  }

  /**
   * @notice Callback function for cross-chain VRF requests
   */
  function receiveRandomWords(uint256[] memory randomWords, uint256 sequence) external nonReentrant {
    require(msg.sender == address(vrfIntegrator), "Only VRF integrator");
    require(randomWords.length > 0, "No random words provided");

    _processVRFCallback(sequence, randomWords[0], RandomnessSource.CROSS_CHAIN_VRF);
  }

  /**
   * @dev Process VRF callback and determine lottery outcome
   */
  function _processVRFCallback(uint256 requestId, uint256 randomness, RandomnessSource source) internal {
    bytes32 entryKey = _getEntryKey(source, requestId);
    PendingLotteryEntry storage entry = pendingEntries[entryKey];
    require(entry.user != address(0), "Invalid request ID");
    require(!entry.fulfilled, "Entry already fulfilled");
    require(entry.randomnessSource == source, "Wrong randomness source");

    entry.fulfilled = true;

    _processLotteryResult(entry.user, entry.swapAmountUSD, entry.winProbability, randomness);

    emit RandomnessFulfilled(requestId, randomness, source);

    delete pendingEntries[entryKey];
  }

  /**
   * @dev Process lottery result and distribute rewards if won
   */
  function _processLotteryResult(
    address user,
    uint256 swapAmountUSD,
    uint256 winProbability,
    uint256 randomness
  ) internal {
    bool won = _isWin(winProbability, randomness);

    uint256 reward = 0;
    if (won) {
      reward = _calculateInstantLotteryReward(swapAmountUSD);

      if (reward > 0) {
        _distributeInstantLotteryReward(user, reward);

        userStats[user].totalWins++;
        userStats[user].totalRewards += reward;
        totalPrizesWon++;
        totalPrizesDistributed += reward;
      }
    }

    emit InstantLotteryProcessed(user, swapAmountUSD, won, reward);
  }

  // ============ HELPER FUNCTIONS ============

  function _calculateInstantLotteryReward(uint256 /* swapAmountUSD */) internal view returns (uint256 reward) {
    if (address(jackpotVault) == address(0)) {
      return 0;
    }

    uint256 currentJackpot;
    try jackpotVault.getJackpotBalance() returns (uint256 jackpot) {
      currentJackpot = jackpot;
    } catch {
      return 0;
    }

    if (currentJackpot == 0) {
      return 0;
    }

    // Calculate partial reward based on configured percentage
    // Note: This is in "jackpot units" - a mix of token amounts
    // The vault will proportionally distribute from each token type
    reward = (currentJackpot * instantLotteryConfig.rewardPercentage) / 10000;
    return reward;
  }

  function _distributeInstantLotteryReward(address winner, uint256 reward) internal {
    if (address(jackpotVault) == address(0) || reward == 0) {
      return;
    }
    
    try jackpotVault.payJackpot(winner, reward) {
      // Success - event will be emitted by _processLotteryResult
    } catch {
      emit PrizeTransferFailed(winner, reward);
    }
  }

  function _calculateLinearWinChance(uint256 swapAmountUSD) internal pure returns (uint256 winChancePPM) {
    if (swapAmountUSD < MIN_SWAP_USD) {
      return 0;
    }

    if (swapAmountUSD >= MAX_PROBABILITY_SWAP_USD) {
      return MAX_WIN_CHANCE_PPM;
    }

    uint256 amountRange = MAX_PROBABILITY_SWAP_USD - MIN_SWAP_USD;
    uint256 chanceRange = MAX_WIN_CHANCE_PPM - MIN_WIN_CHANCE_PPM;
    uint256 amountDelta = swapAmountUSD - MIN_SWAP_USD;

    winChancePPM = MIN_WIN_CHANCE_PPM + (chanceRange * amountDelta) / amountRange;

    return winChancePPM;
  }

  /**
   * @notice Apply veDRAGON boost to lottery probability PROPORTIONALLY based on locked amount
   * @param user User address to calculate boost for
   * @param baseProbability Base win probability in PPM
   * @param swapAmountUSD USD value of the swap
   * @return boostedProbability Proportionally boosted probability (capped at MAX_WIN_PROBABILITY_PPM)
   */
  function _applyVeDRAGONBoost(
    address user,
    uint256 baseProbability,
    uint256 swapAmountUSD
  ) internal view returns (uint256) {
    // Use veDRAGONBoostManager as the single source of truth for all boost calculations
    if (address(veDRAGONBoostManager) != address(0)) {
      try veDRAGONBoostManager.calculateBoost(user) returns (uint256 boostMultiplierBPS) {
        // Cap boost from external source to prevent misconfiguration
        if (boostMultiplierBPS > MAX_BOOST_BPS) {
          boostMultiplierBPS = MAX_BOOST_BPS;
        }
        
        // Get user's locked USD value
        uint256 lockedUSDValue = _getUserLockedUSDValue(user);
        
        if (lockedUSDValue == 0) {
          return baseProbability; // No boost if no locked value
        }
        
        // Calculate proportional boost
        uint256 boostedPortion = swapAmountUSD > lockedUSDValue ? lockedUSDValue : swapAmountUSD;
        uint256 unboostedPortion = swapAmountUSD - boostedPortion;
        
        // Calculate boost multiplier (10000 = 100%, 25000 = 250%)
        uint256 boostMultiplier = (boostMultiplierBPS * BOOST_PRECISION) / 10000;
        
        // Apply boost proportionally
        uint256 boostedProbPortion = (baseProbability * boostedPortion * boostMultiplier) / (swapAmountUSD * BOOST_PRECISION);
        uint256 unboostedProbPortion = (baseProbability * unboostedPortion) / swapAmountUSD;
        
        uint256 totalBoostedProbability = boostedProbPortion + unboostedProbPortion;
        
        // Cap at maximum win probability
        return totalBoostedProbability > MAX_WIN_PROBABILITY_PPM ? MAX_WIN_PROBABILITY_PPM : totalBoostedProbability;
      } catch {
        // If boost manager fails, return base probability without boost
        return baseProbability;
      }
    }

    // If boost manager not set, return base probability without boost
    return baseProbability;
  }



  /**
   * @notice Get user's locked USD value via redDRAGON → LP tokens → USD calculation
   * @param user User address
   * @return USD value of locked tokens (scaled by 1e6)
   */
  function _getUserLockedUSDValue(address user) internal view returns (uint256) {
    if (address(redDRAGONToken) == address(0)) {
      return 0;
    }
    
    // Step 1: Get user's locked redDRAGON amount from veDRAGON
    uint256 lockedRedDragonAmount = _getLockedRedDragonAmount(user);
    if (lockedRedDragonAmount == 0) {
      return 0;
    }
    
    // Step 2: Convert redDRAGON shares to underlying DRAGON/wS LP tokens (ERC-4626)
    try IredDRAGON(address(redDRAGONToken)).convertToAssets(lockedRedDragonAmount) returns (uint256 underlyingLP) {
      if (underlyingLP == 0) return 0;
      
      // Step 3: Calculate USD value of DRAGON/wS LP tokens
      return _calculateLPTokenUSDValue(underlyingLP);
    } catch {
      return 0;
    }
  }
  
  /**
   * @notice Get user's locked redDRAGON amount from veDRAGON contract
   * @param user User address
   * @return Amount of redDRAGON tokens locked
   */
  function _getLockedRedDragonAmount(address user) internal view returns (uint256) {
    if (address(veDRAGONToken) == address(0)) {
      return 0;
    }
    
    try IveDRAGONToken(address(veDRAGONToken)).locked(user) returns (uint256 amount, uint256 unlockTime) {
      // Only return amount if lock hasn't expired
      if (unlockTime > block.timestamp) {
        return amount;
      }
      return 0;
    } catch {
      return 0;
    }
  }
  
  /**
   * @notice Convert token amount to USD value (1e6 scale)
   * @param token Token address
   * @param amount Token amount in native decimals
   * @return USD value scaled by 1e6
   */
  function _amountToUsd1e6(address token, uint256 amount) internal view returns (uint256) {
    if (amount == 0) return 0;
    
    address oracle = tokenUsdOracle[token];
    if (oracle == address(0)) return 0;
    
    try IPriceOracleLike(oracle).getLatestPrice() returns (int256 price1e18, uint256) {
      if (price1e18 <= 0) return 0;
      
      uint8 decimals;
      try IERC20Metadata(token).decimals() returns (uint8 d) {
        decimals = d;
      } catch {
        decimals = 18; // Default to 18 if decimals() fails
      }
      
      // USD(1e6) = amount * price(1e18) / (10^decimals * 1e12)
      return (amount * uint256(price1e18)) / (10 ** decimals) / 1e12;
    } catch {
      return 0;
    }
  }

  /**
   * @notice Calculate USD value of DRAGON/wS LP tokens
   * @param lpAmount Amount of LP tokens
   * @return USD value (scaled by 1e6)
   */
  function _calculateLPTokenUSDValue(uint256 lpAmount) internal view returns (uint256) {
    if (lpAmount == 0 || address(redDRAGONToken) == address(0)) {
      return 0;
    }
    
    try IredDRAGON(address(redDRAGONToken)).asset() returns (address lpToken) {
      if (lpToken == address(0)) return 0;
      
      IUniswapV2Pair pair = IUniswapV2Pair(lpToken);
      
      // Get reserves and total supply
      (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
      uint256 totalSupply = pair.totalSupply();
      
      if (totalSupply == 0) return 0;
      
      // Calculate user's share of reserves
      uint256 userAmount0 = (uint256(reserve0) * lpAmount) / totalSupply;
      uint256 userAmount1 = (uint256(reserve1) * lpAmount) / totalSupply;
      
      // Get token addresses
      address token0 = pair.token0();
      address token1 = pair.token1();
      
      // Calculate USD value for each side using configured oracles
      uint256 usd0 = _amountToUsd1e6(token0, userAmount0);
      uint256 usd1 = _amountToUsd1e6(token1, userAmount1);
      
      return usd0 + usd1;
      
    } catch {
      // If redDRAGON asset lookup fails, return 0
      return 0;
    }
  }

  // ============ VIEW FUNCTIONS ============

  function getInstantLotteryConfig()
    external
    view
    returns (
      uint256 minSwapAmount,
      uint256 rewardPercentage,
      bool isActive,
      bool useVRFForInstant,
      bool enablePriceUpdates
    )
  {
    return (
      instantLotteryConfig.minSwapAmount,
      instantLotteryConfig.rewardPercentage,
      instantLotteryConfig.isActive,
      instantLotteryConfig.useVRFForInstant,
      instantLotteryConfig.enablePriceUpdates
    );
  }

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

  function calculateWinProbability(
    address user,
    uint256 swapAmountUSD
  ) external view returns (uint256 baseProbability, uint256 boostedProbability) {
    baseProbability = _calculateLinearWinChance(swapAmountUSD);
    boostedProbability = _applyVeDRAGONBoost(user, baseProbability, swapAmountUSD);

    if (boostedProbability > MAX_WIN_PROBABILITY_PPM) {
      boostedProbability = MAX_WIN_PROBABILITY_PPM;
    }
  }

  /**
   * @notice Test proportional boost calculation with example values
   * @param user User address to test
   * @param swapAmountUSD Swap amount in USD
   * @return lockedUSD User's locked USD value
   * @return boostedPortion Amount that gets boosted
   * @return unboostedPortion Amount that doesn't get boosted
   * @return boostMultiplier The boost multiplier applied
   * @return finalProbability The final proportional probability
   */
  function testProportionalBoost(
    address user,
    uint256 swapAmountUSD
  ) external view returns (
    uint256 lockedUSD,
    uint256 boostedPortion,
    uint256 unboostedPortion,
    uint256 boostMultiplier,
    uint256 finalProbability
  ) {
    uint256 baseProbability = _calculateLinearWinChance(swapAmountUSD);
    lockedUSD = _getUserLockedUSDValue(user);
    
    if (lockedUSD == 0) {
      return (0, 0, swapAmountUSD, 10000, baseProbability);
    }
    
    boostedPortion = swapAmountUSD > lockedUSD ? lockedUSD : swapAmountUSD;
    unboostedPortion = swapAmountUSD - boostedPortion;
    
    if (address(veDRAGONBoostManager) != address(0)) {
      try veDRAGONBoostManager.calculateBoost(user) returns (uint256 boostBPS) {
        boostMultiplier = boostBPS;
      } catch {
        boostMultiplier = 10000; // 1x if failed
      }
    } else {
      boostMultiplier = 10000; // 1x if not set
    }
    
    finalProbability = _applyVeDRAGONBoost(user, baseProbability, swapAmountUSD);
  }

  function getCurrentJackpot() external view returns (uint256) {
    if (address(jackpotVault) == address(0)) {
      return 0;
    }
    try jackpotVault.getJackpotBalance() returns (uint256 bal) {
      return bal;
    } catch {
      return 0;
    }
  }

  function getVrfFee() external view returns (uint256) {
    if (address(vrfIntegrator) == address(0)) return 0;
    MessagingFee memory feeQuote = vrfIntegrator.quoteFee();
    return feeQuote.nativeFee;
  }

  function fundVrf() external payable onlyOwner {}

  /**
   * @dev Accept native S deposits for VRF funding and contract operations
   */
  receive() external payable {
    emit VRFFunded(msg.sender, msg.value);
  }

  /**
   * @dev Fallback function to accept native S
   */
  fallback() external payable {
    emit VRFFunded(msg.sender, msg.value);
  }

  // ============ ECOSYSTEM INTEGRATION HELPERS ============

  /**
   * @notice Check if this lottery manager is properly configured for the ecosystem
   * @return isConfigured Whether all required components are set
   * @return missingComponents Array of missing component names
   */
  function checkEcosystemIntegration() 
    external 
    view 
    returns (bool isConfigured, string[] memory missingComponents) 
  {
    string[] memory missing = new string[](10);
    uint256 missingCount = 0;

    // Check appropriate oracle based on chain
    if (CHAIN_ID == SONIC_CHAIN_ID) {
      if (address(primaryOracle) == address(0)) {
        missing[missingCount] = "primaryOracle";
        missingCount++;
      }
    } else {
      if (priceOracle == address(0)) {
        missing[missingCount] = "priceOracle";
        missingCount++;
      }
    }
    if (address(vrfIntegrator) == address(0)) {
      missing[missingCount] = "vrfIntegrator";
      missingCount++;
    }
    if (address(jackpotVault) == address(0)) {
      missing[missingCount] = "jackpotVault";
      missingCount++;
    }
    if (address(veDRAGONToken) == address(0)) {
      missing[missingCount] = "veDRAGONToken";
      missingCount++;
    }
    if (address(veDRAGONBoostManager) == address(0)) {
      missing[missingCount] = "veDRAGONBoostManager";
      missingCount++;
    }

    // Create properly sized array
    string[] memory result = new string[](missingCount);
    for (uint256 i = 0; i < missingCount; i++) {
      result[i] = missing[i];
    }

    return (missingCount == 0, result);
  }

  /**
   * @notice Test the boost calculation for a user to verify veDRAGON integration
   * @param user User address to test
   * @param testAmount Test swap amount in USD (6 decimals)
   * @return baseProbability Calculated base probability
   * @return boostedProbability Boosted probability after veDRAGON boost
   * @return boostMultiplier Effective boost multiplier applied
   */
  function testBoostCalculation(
    address user,
    uint256 testAmount
  ) external view returns (
    uint256 baseProbability,
    uint256 boostedProbability,
    uint256 boostMultiplier
  ) {
    baseProbability = _calculateLinearWinChance(testAmount);
    boostedProbability = _applyVeDRAGONBoost(user, baseProbability, testAmount);
    
    if (baseProbability > 0) {
      boostMultiplier = (boostedProbability * BOOST_PRECISION) / baseProbability;
    } else {
      boostMultiplier = BOOST_PRECISION;
    }
  }

  /**
   * @notice Get user's veDRAGON information for debugging
   * @param user User address
   * @return veDRAGONBalance User's veDRAGON balance
   * @return redDRAGONBalance User's redDRAGON balance  
   * @return votingPower User's voting power (if available)
   * @return boostManagerBoost Boost from boost manager (if available)
   */
  function getUserVeDRAGONInfo(address user) 
    external 
    view 
    returns (
      uint256 veDRAGONBalance,
      uint256 redDRAGONBalance,
      uint256 votingPower,
      uint256 boostManagerBoost
    ) 
  {
    // Get veDRAGON balance
    if (address(veDRAGONToken) != address(0)) {
      try veDRAGONToken.balanceOf(user) returns (uint256 balance) {
        veDRAGONBalance = balance;
      } catch {
        veDRAGONBalance = 0;
      }

      try IveDRAGON(address(veDRAGONToken)).getVotingPower(user) returns (uint256 vp) {
        votingPower = vp;
      } catch {
        votingPower = 0;
      }
    }

    // Get redDRAGON balance
    if (address(redDRAGONToken) != address(0)) {
      try redDRAGONToken.balanceOf(user) returns (uint256 balance) {
        redDRAGONBalance = balance;
      } catch {
        redDRAGONBalance = 0;
      }
    }

    // Get boost manager boost
    if (address(veDRAGONBoostManager) != address(0)) {
      try veDRAGONBoostManager.calculateBoost(user) returns (uint256 boost) {
        boostManagerBoost = boost;
      } catch {
        boostManagerBoost = 0;
      }
    }
  }

  // ============ HELPER FUNCTIONS (CONTINUED) ============

  /**
   * @notice Generate composite key for pending entries
   * @param source Randomness source type
   * @param id Request ID
   * @return Composite key
   */
  function _getEntryKey(RandomnessSource source, uint256 id) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(uint8(source), id));
  }

  /**
   * @notice Bias-free random win check
   * @param ppm Win probability in parts per million (0-1,000,000)
   * @param rnd Random number from VRF
   * @return Whether the user won
   */
  function _isWin(uint256 ppm, uint256 rnd) internal pure returns (bool) {
    if (ppm == 0) return false;
    if (ppm >= 1_000_000) return true;
    unchecked {
      // threshold = floor(max / 1_000_000) * ppm
      uint256 bucket = type(uint256).max / 1_000_000;
      uint256 threshold = bucket * ppm;
      return rnd < threshold;
    }
  }

  // ============ SONIC FEEM INTEGRATION ============

  function registerMe() external onlyOwner {
    (bool _success,) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
        abi.encodeWithSignature("selfRegister(uint256)", 143)
    );
    require(_success, "FeeM registration failed");
  }

  // ============ ADMIN FUNCTIONS (SAFETY) ============

  /**
   * @notice Pause lottery operations
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Unpause lottery operations
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  /**
   * @notice Set target EID for cross-chain VRF
   * @param _targetEid LayerZero endpoint ID
   */
  function setTargetEid(uint32 _targetEid) external onlyOwner {
    require(_targetEid > 0, "Invalid EID");
    targetEid = _targetEid;
  }

  /**
   * @notice Withdraw native tokens (for emergencies)
   * @param to Recipient address
   * @param amount Amount to withdraw
   */
  function withdrawNative(address payable to, uint256 amount) external onlyOwner {
    require(to != address(0), "Invalid recipient");
    require(amount <= address(this).balance, "Insufficient balance");
    
    (bool success,) = to.call{value: amount}("");
    require(success, "Transfer failed");
  }

  /**
   * @notice Recover stuck tokens
   * @param token Token to recover
   * @param to Recipient address
   * @param amount Amount to recover
   */
  function recoverToken(IERC20 token, address to, uint256 amount) external onlyOwner {
    require(to != address(0), "Invalid recipient");
    token.safeTransfer(to, amount);
  }

  /**
   * @notice Set token USD oracle
   * @param token Token address
   * @param oracle Oracle address that provides TOKEN/USD price (1e18 scale)
   */
  function setTokenUsdOracle(address token, address oracle) external onlyOwner {
    require(token != address(0), "Invalid token");
    require(oracle != address(0), "Invalid oracle");
    
    tokenUsdOracle[token] = oracle;
    emit TokenUsdOracleSet(token, oracle);
  }

  /**
   * @notice Unset token USD oracle
   * @param token Token address
   */
  function unsetTokenUsdOracle(address token) external onlyOwner {
    require(token != address(0), "Invalid token");
    
    tokenUsdOracle[token] = address(0);
    emit TokenUsdOracleSet(token, address(0));
  }

  /**
   * @notice Set max gas for oracle price updates
   * @param _maxGas Maximum gas limit
   */
  function setMaxPriceUpdateGas(uint256 _maxGas) external onlyOwner {
    require(_maxGas >= 100_000 && _maxGas <= 2_000_000, "Gas limit out of range");
    maxPriceUpdateGas = _maxGas;
  }
}
