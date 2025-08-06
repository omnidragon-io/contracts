// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "solmate/src/tokens/ERC4626.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../../interfaces/tokens/IredDRAGON.sol";
import "../../interfaces/lottery/IOmniDragonLotteryManager.sol";

// Custom Errors
error ZeroAddress();
error InvalidAmount();
error TradingDisabled();
error ContractPaused();
error InvalidFeeConfiguration();
error SwapInProgress();
error TransferFailed();
error NotInitialized();
error AlreadyInitialized();
error InvalidWeights();

// Event Categories for gas optimization (matching omniDRAGON pattern)
enum EventCategory {
  BUY_JACKPOT,
  BUY_REVENUE,
  SELL_JACKPOT,
  SELL_REVENUE,
  LOTTERY_ENTRY,
  FEE_PROCESSING
}

/**
 * @title redDRAGON
 * @author 0xakita.eth
 * @dev An ERC-4626 vault for Uniswap V2 LP tokens (DRAGON/wrappedNative) with fees and lottery integration
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
 *
 * FEES:
 * - Buy/Sell transactions: 6.9% fee (immediate distribution)
 * - Regular transfers: No fees
 * - Fee distribution: 69% jackpot, 31% veDRAGON holders
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract redDRAGON is ERC4626, Ownable, ReentrancyGuard, Pausable {
  using SafeTransferLib for ERC20;

  // ========== CONSTANTS ==========

  uint256 public constant BASIS_POINTS = 10000; // 100%
  address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  // Fee structure constants (6.9% total fee)
  uint256 public constant DEFAULT_SWAP_FEE_BPS = 690; // 6.9% total fee
  uint256 public constant DEFAULT_JACKPOT_SHARE_BPS = 6900; // 69% of fees go to jackpot
  uint256 public constant DEFAULT_REVENUE_SHARE_BPS = 3100; // 31% of fees go to revenue
  uint256 public constant MAX_FEE_BPS = 2500; // 25% maximum fee

  // Lottery constants (matching OmniDragonLotteryManager exactly)
  uint256 public constant MIN_SWAP_USD = 10e6; // $10 USD minimum (6 decimals)
  uint256 public constant MAX_PROBABILITY_SWAP_USD = 10000e6; // $10,000 USD for max probability (6 decimals)
  uint256 public constant MIN_WIN_CHANCE_PPM = 40; // 0.004% (40 PPM)
  uint256 public constant MAX_WIN_CHANCE_PPM = 40000; // 4% (40,000 PPM)
  uint256 public constant MAX_WIN_PROBABILITY_PPM = 100000; // 10% maximum win probability (100,000 PPM)

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

  // ========== STATE VARIABLES ==========

  bool public initialized;
  bool public tradingEnabled = true;
  bool public feesEnabled = true;

  // Configuration
  SwapConfig public swapConfig;
  LotteryConfig public lotteryConfig;

  // DEX pair tracking
  mapping(address => bool) public isPair;
  mapping(address => bool) public isExcludedFromFees;

  // Fee processing (removed - using immediate distribution)
  bool private inSwap;

  // Statistics
  uint256 public totalJackpotFees;
  uint256 public totalRevenueFees;
  uint256 public totalTradesProcessed;
  uint256 public totalLotteryEntries;

  // ========== EVENTS ==========

  event TradingEnabled(uint256 timestamp);
  event TradingPaused(uint256 timestamp);
  event PairUpdated(address indexed pair, bool indexed isPair);
  event FeeExclusionUpdated(address indexed account, bool excluded);
  event ImmediateDistributionExecuted(address indexed recipient, uint256 amount, EventCategory distributionType);

  // ========== MODIFIERS ==========

  modifier onlyInitialized() {
    if (!initialized) revert NotInitialized();
    _;
  }

  modifier notPaused() {
    if (paused()) revert TradingDisabled();
    _;
  }

  modifier lockSwap() {
    inSwap = true;
    _;
    inSwap = false;
  }

  modifier validAddress(address _addr) {
    if (_addr == address(0)) revert ZeroAddress();
    _;
  }

  // ========== CONSTRUCTOR ==========

  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol
  ) ERC4626(_asset, _name, _symbol) Ownable(msg.sender) {
    // Initialize with lottery configuration matching OmniDragonLotteryManager
    lotteryConfig = LotteryConfig({
      minSwapUSD: MIN_SWAP_USD,
      maxSwapUSD: MAX_PROBABILITY_SWAP_USD,
      minProbabilityPPM: MIN_WIN_CHANCE_PPM,
      maxProbabilityPPM: MAX_WIN_CHANCE_PPM,
      enabled: true
    });

    // Exclude contract from fees
    isExcludedFromFees[address(this)] = true;
  }

  // ========== ERC4626 IMPLEMENTATION ==========

  /**
   * @notice Total amount of underlying LP tokens held by vault
   * @dev This increases over time as LP tokens auto-compound from trading fees
   */
  function totalAssets() public view override returns (uint256) {
    return asset.balanceOf(address(this));
  }

  /**
   * @notice Deposit LP tokens and receive redDRAGON shares
   * @param assets Amount of LP tokens to deposit
   * @param receiver Address to receive shares
   * @return shares Amount of shares minted
   */
  function deposit(
    uint256 assets,
    address receiver
  ) public override onlyInitialized notPaused nonReentrant returns (uint256 shares) {
    // Check for sufficient assets and valid receiver
    if (assets == 0) revert InvalidAmount();
    if (receiver == address(0)) revert ZeroAddress();

    // Calculate shares to mint
    shares = previewDeposit(assets);

    // Deposit assets from sender
    asset.safeTransferFrom(msg.sender, address(this), assets);

    // Mint shares to receiver
    _mint(receiver, shares);

    emit Deposit(msg.sender, receiver, assets, shares);
  }

  /**
   * @notice Withdraw LP tokens by burning redDRAGON shares
   * @param assets Amount of LP tokens to withdraw
   * @param receiver Address to receive assets
   * @param owner Address that owns the shares
   * @return shares Amount of shares burned
   */
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override onlyInitialized notPaused nonReentrant returns (uint256 shares) {
    if (assets == 0) revert InvalidAmount();
    if (receiver == address(0)) revert ZeroAddress();

    shares = previewWithdraw(assets);

    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }

    // Burn shares from owner
    _burn(owner, shares);

    // Transfer assets to receiver
    asset.safeTransfer(receiver, assets);

    emit Withdraw(msg.sender, receiver, owner, assets, shares);
  }

  // ========== FEE-ON-TRANSFER OVERRIDE ==========

  /**
   * @notice Override transfer to implement fee-on-transfer for DEX pairs
   */
  function transfer(address to, uint256 amount) public override(ERC20) notPaused nonReentrant returns (bool) {
    if (amount == 0) return true;

    // Check if this is a DEX pair transaction that should trigger fees
    bool shouldTakeFees = feesEnabled &&
      !inSwap &&
      (isPair[msg.sender] || isPair[to]) &&
      !isExcludedFromFees[msg.sender] &&
      !isExcludedFromFees[to];

    if (shouldTakeFees) {
      return _transferWithFees(msg.sender, to, amount);
    } else {
      // Regular transfer without fees
      balanceOf[msg.sender] -= amount;

      // Cannot overflow because the sum of all user
      // balances can't exceed the max uint256 value.
      unchecked {
        balanceOf[to] += amount;
      }

      emit Transfer(msg.sender, to, amount);
      return true;
    }
  }

  /**
   * @notice Override transferFrom to implement fee-on-transfer for DEX pairs
   */
  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public override(ERC20) notPaused nonReentrant returns (bool) {
    if (amount == 0) return true;

    uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

    if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

    // Check if this is a DEX pair transaction that should trigger fees
    bool shouldTakeFees = feesEnabled &&
      !inSwap &&
      (isPair[from] || isPair[to]) &&
      !isExcludedFromFees[from] &&
      !isExcludedFromFees[to];

    if (shouldTakeFees) {
      return _transferWithFees(from, to, amount);
    } else {
      // Regular transfer without fees
      balanceOf[from] -= amount;

      // Cannot overflow because the sum of all user
      // balances can't exceed the max uint256 value.
      unchecked {
        balanceOf[to] += amount;
      }

      emit Transfer(from, to, amount);
      return true;
    }
  }

  /**
   * @notice Internal function to handle transfers with fees
   */
  function _transferWithFees(address from, address to, uint256 amount) internal lockSwap returns (bool) {
    uint256 feeAmount = (amount * DEFAULT_SWAP_FEE_BPS) / BASIS_POINTS;
    uint256 transferAmount = amount - feeAmount;

    // Transfer amount minus fees
    balanceOf[from] -= amount;

    unchecked {
      balanceOf[to] += transferAmount;
      if (feeAmount > 0) {
        balanceOf[address(this)] += feeAmount;
      }
    }

    emit Transfer(from, to, transferAmount);
    if (feeAmount > 0) {
      emit Transfer(from, address(this), feeAmount);
    }

    // Distribute fees immediately
    if (feeAmount > 0) {
      _distributeFees(feeAmount, isPair[from] ? "buy" : "sell");
    }

    // Trigger lottery for buy transactions only
    if (isPair[from] && transferAmount > 0 && swapConfig.lotteryManager != address(0)) {
      try IOmniDragonLotteryManager(swapConfig.lotteryManager).processSwapLottery(
        to,             // trader
        address(this),  // tokenIn
        transferAmount, // amountIn
        0              // swapValueUSD (let lottery manager calculate)
      ) {
        totalLotteryEntries++;
      } catch {
        // Silent failure - lottery is optional
      }
    }

    totalTradesProcessed++;
    return true;
  }

  /**
   * @notice Distribute fees immediately to jackpot vault and revenue distributor
   */
  function _distributeFees(uint256 feeAmount, string memory transactionType) internal {
    if (feeAmount == 0) return;

    uint256 jackpotAmount = (feeAmount * DEFAULT_JACKPOT_SHARE_BPS) / BASIS_POINTS;
    uint256 revenueAmount = feeAmount - jackpotAmount;

    // Transfer to jackpot vault
    if (jackpotAmount > 0 && swapConfig.jackpotVault != address(0)) {
      balanceOf[address(this)] -= jackpotAmount;
      unchecked {
        balanceOf[swapConfig.jackpotVault] += jackpotAmount;
      }
      emit Transfer(address(this), swapConfig.jackpotVault, jackpotAmount);

      EventCategory category = keccak256(bytes(transactionType)) == keccak256(bytes("buy"))
        ? EventCategory.BUY_JACKPOT
        : EventCategory.SELL_JACKPOT;
      emit ImmediateDistributionExecuted(swapConfig.jackpotVault, jackpotAmount, category);
      totalJackpotFees += jackpotAmount;
    }

    // Transfer to revenue distributor
    if (revenueAmount > 0 && swapConfig.revenueDistributor != address(0)) {
      balanceOf[address(this)] -= revenueAmount;
      unchecked {
        balanceOf[swapConfig.revenueDistributor] += revenueAmount;
      }
      emit Transfer(address(this), swapConfig.revenueDistributor, revenueAmount);

      EventCategory category = keccak256(bytes(transactionType)) == keccak256(bytes("buy"))
        ? EventCategory.BUY_REVENUE
        : EventCategory.SELL_REVENUE;
      emit ImmediateDistributionExecuted(swapConfig.revenueDistributor, revenueAmount, category);
      totalRevenueFees += revenueAmount;
    }
  }

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
  ) external onlyOwner {
    if (initialized) revert AlreadyInitialized();
    if (_owner == address(0)) revert ZeroAddress();

    // Initialize swap configuration
    swapConfig = SwapConfig({
      jackpotVault: _jackpotVault,
      revenueDistributor: _revenueDistributor,
      lotteryManager: _lotteryManager
    });

    // Transfer ownership to specified owner
    if (_owner != owner()) {
      _transferOwnership(_owner);
    }

    initialized = true;
  }

  // ========== ADMIN FUNCTIONS ==========

  /**
   * @notice Set DEX pair status
   * @param pair Pair address
   * @param _isPair Whether address is a DEX pair
   */
  function setPair(address pair, bool _isPair) external onlyOwner validAddress(pair) {
    isPair[pair] = _isPair;
    emit PairUpdated(pair, _isPair);
  }

  /**
   * @notice Set fee exclusion status
   * @param account Account to exclude/include
   * @param excluded Whether account is excluded from fees
   */
  function setExcludeFromFees(address account, bool excluded) external onlyOwner validAddress(account) {
    isExcludedFromFees[account] = excluded;
    emit FeeExclusionUpdated(account, excluded);
  }

  /**
   * @notice Set contract pause state
   * @param _paused Whether to pause the contract
   */
  function setPaused(bool _paused) external onlyOwner {
    if (_paused) {
      _pause();
      emit TradingPaused(block.timestamp);
    } else {
      _unpause();
      emit TradingEnabled(block.timestamp);
    }
  }

  // ========== FEEM INTEGRATION ==========

  /**
   * @notice Register with Sonic FeeM system
   * @dev Register my contract on Sonic FeeM for network benefits
   */
  function registerMe() external onlyOwner {
    (bool _success,) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
        abi.encodeWithSignature("selfRegister(uint256)", 143)
    );
    require(_success, "FeeM registration failed");
  }

  // ========== VIEW FUNCTIONS ==========

  /**
   * @notice Get current swap configuration
   * @return config Current swap configuration
   */
  function getSwapConfig() external view returns (SwapConfig memory config) {
    return swapConfig;
  }

  /**
   * @notice Get current lottery configuration
   * @return config Current lottery configuration
   */
  function getLotteryConfig() external view returns (LotteryConfig memory config) {
    return lotteryConfig;
  }

  /**
   * @notice Get USD value of redDRAGON shares (simplified - no oracle needed)
   * @return usdValue Always returns 0 (price oracle removed for simplicity)
   */
  function getUSDValue(address /* token */, uint256 /* amount */) public pure returns (uint256 usdValue) {
    return 0; // Simplified - no price oracle integration
  }

  /**
   * @notice Check if address is authorized swap contract
   * @dev Deprecated in pair-based model
   * @return authorized Always returns false
   */
  function isAuthorizedSwapContract(address /* swapContract */) external pure returns (bool authorized) {
    return false; // Deprecated in pair-based model
  }

  /**
   * @notice Get total fees collected
   * @return jackpotFees Total fees sent to jackpot
   * @return revenueFees Total fees sent to revenue distributor
   */
  function getTotalFees() external view returns (uint256 jackpotFees, uint256 revenueFees) {
    return (totalJackpotFees, totalRevenueFees);
  }

  /**
   * @notice Check if contract is initialized
   * @return initialized Whether contract is initialized
   */
  function isInitialized() external view returns (bool) {
    return initialized;
  }

  /**
   * @notice Get underlying LP token address
   * @return lpToken Address of underlying LP token
   */
  function getUnderlyingLPToken() external view returns (address lpToken) {
    return address(asset);
  }

  /**
   * @notice Get comprehensive vault statistics
   * @return stats Array of key statistics
   */
  function getStats() external view returns (uint256[6] memory stats) {
    return
      [
        totalSupply, // Total redDRAGON shares
        totalAssets(), // Total LP tokens in vault
        totalJackpotFees,
        totalRevenueFees,
        totalTradesProcessed,
        totalLotteryEntries
      ];
  }
}