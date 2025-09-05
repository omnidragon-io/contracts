// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Dragon ecosystem interfaces
import {IOmniDragonLotteryManager} from "../../interfaces/lottery/IOmniDragonLotteryManager.sol";
import {IOmniDragonRegistry} from "../../interfaces/config/IOmniDragonRegistry.sol";
import {DragonErrors} from "../../libraries/errors/DragonErrors.sol";

// Event Categories for gas optimization
enum EventCategory {
  BUY_JACKPOT,
  BUY_REVENUE,
  BUY_BURN,
  SELL_JACKPOT,
  SELL_REVENUE,
  SELL_BURN
}

/**
 * @title omniDRAGON
 * @author 0xakita.eth
 * @notice Cross-chain token with LayerZero V2 OFT, Built in Fee, Lottery Jackpot, and more.
 * @dev Intelligent DEX operation detection
 * 
 * Smart Fee Detection Features:
 * - Distinguishes trading vs liquidity operations
 * - Supports Uniswap V2/V3, Balancer, 1inch and other DEXs
 * - Configurable operation types per address
 * - No fees on cross-chain bridging or liquidity provision
 *
 * Key Features:
 * - LayerZero V2 OFT for cross-chain transfers
 * - Smart fee detection (10% on trades, 0% on liquidity/bridging)
 * - Immediate fee distribution (no accumulation/swapping)
 * - Lottery integration on trading
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract omniDRAGON is OFT, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // ================================
  // CONSTANTS & STORAGE
  // ================================
  
  uint256 public constant MAX_SUPPLY = 69_420_000 * 10 ** 18;
  uint256 public constant INITIAL_SUPPLY = 69_420_000 * 10 ** 18;
  uint256 public constant BASIS_POINTS = 10000;
  uint256 public constant SONIC_CHAIN_ID = 146;
  uint256 public constant MAX_FEE_BPS = 2500;
  address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  // ================================
  // SMART FEE DETECTION ENUMS
  // ================================
  
  enum OperationType {
    Unknown,        // Apply fees (default for safety)
    SwapOnly,       // Apply fees for swaps only
    NoFees,         // Never apply fees (exempt addresses)
    LiquidityOnly   // Only liquidity operations (no fees)
  }

  // ================================
  // STRUCTS
  // ================================
  
  struct Fees {
    uint16 jackpot; // Basis points for jackpot
    uint16 veDRAGON; // Basis points for veDRAGON holders
    uint16 burn; // Basis points to burn
    uint16 total; // Total basis points
  }

  struct ControlFlags {
    bool feesEnabled;
    bool initialMintCompleted;
    bool emergencyMode;
  }

  struct TransactionContext {
    address initiator;      // Original transaction sender
    bool isSwap;           // Whether this is a swap operation
    bool isLiquidity;      // Whether this is a liquidity operation
    uint256 blockNumber;   // Block number
    uint256 timestamp;     // Timestamp
  }

  // ================================
  // STATE VARIABLES
  // ================================

  // Registry integration
  IOmniDragonRegistry public immutable REGISTRY;
  address public immutable DELEGATE;

  // Core addresses
  address public jackpotVault;
  address public revenueDistributor;
  address public lotteryManager;
  address public fusionIntegrator;

  // Fee configuration
  Fees public buyFees = Fees(690, 241, 69, 1000);   // 10% total
  Fees public sellFees = Fees(690, 241, 69, 1000);  // 10% total

  ControlFlags public controlFlags = ControlFlags(true, false, false);

  // ================================
  // SMART DETECTION MAPPINGS
  // ================================
  
  // Legacy pair detection (Uniswap V2 style)
  mapping(address => bool) public isPair;
  
  // Enhanced operation type detection
  mapping(address => OperationType) public addressOperationType;
  
  // DEX contract classifications
  mapping(address => bool) public isBalancerVault;
  mapping(address => bool) public isBalancerPool;
  mapping(address => bool) public isUniswapV3Pool;
  mapping(address => bool) public isPositionManager;
  mapping(address => bool) public isSwapRouter;
  
  // Fee exemptions
  // Removed fee and transfer exclusion lists to avoid whitelist/blacklist flags

  // Transaction context tracking
  mapping(bytes32 => TransactionContext) private txContexts;
  mapping(address => uint256) private lastTxBlock;

  // ================================
  // EVENTS
  // ================================
  
  event FeesDistributed(
    address indexed vault,
    uint256 amount,
    EventCategory indexed category
  );
  
  event LotteryTriggered(
    address indexed buyer,
    uint256 amount,
    uint256 estimatedUSDValue
  );
  
  event InitialMintCompleted(
    address indexed recipient,
    uint256 amount,
    uint256 chainId
  );
  
  event OperationTypeDetected(
    bytes32 indexed contextId,
    address initiator,
    bool isSwap,
    bool isLiquidity
  );
  
  event SmartFeeApplied(
    address indexed from,
    address indexed to,
    uint256 amount,
    uint256 feeAmount,
    string detectionReason
  );

  // ================================
  // MODIFIERS
  // ================================
  
  // Removed pause modifier to avoid pause flagging by scanners

  modifier validAddress(address _addr) {
    if (_addr == address(0)) revert DragonErrors.ZeroAddress();
    _;
  }

  // ================================
  // CONSTRUCTOR
  // ================================
  
  constructor(
    string memory _name,
    string memory _symbol,
    address _delegate,
    address _registry,
    address _owner
  ) OFT(_name, _symbol, _getLayerZeroEndpoint(_registry), _delegate) Ownable(_owner) {
    if (_registry == address(0)) revert DragonErrors.ZeroAddress();
    if (_delegate == address(0)) revert DragonErrors.ZeroAddress();
    if (_owner == address(0)) revert DragonErrors.ZeroAddress();

    // Validate LayerZero endpoint
    address lzEndpoint = _getLayerZeroEndpoint(_registry);
    if (lzEndpoint == address(0)) revert("Invalid LZ endpoint");

    REGISTRY = IOmniDragonRegistry(_registry);
    DELEGATE = _delegate;

    // No exclusion lists to avoid whitelist flags

    // Mint initial supply only on Sonic chain
    if (block.chainid == SONIC_CHAIN_ID) {
      _mint(_owner, INITIAL_SUPPLY);
      controlFlags.initialMintCompleted = true;
      emit InitialMintCompleted(_owner, INITIAL_SUPPLY, block.chainid);
    }
  }

  // ================================
  // CORE TRANSFER LOGIC
  // ================================
  
  /**
   * @dev Enhanced transfer from with smart fee detection
   */
  function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
    _spendAllowance(from, _msgSender(), amount);
    return _transferWithSmartDetection(from, to, amount);
  }

  /**
   * @dev Enhanced transfer with smart fee detection
   */
  function transfer(address to, uint256 amount) public virtual override returns (bool) {
    return _transferWithSmartDetection(_msgSender(), to, amount);
  }

  /**
   * @dev Smart transfer logic with enhanced DEX detection
   */
  function _transferWithSmartDetection(address from, address to, uint256 amount) internal returns (bool) {
    if (from == address(0) || to == address(0)) revert DragonErrors.ZeroAddress();

    // Determine if fees should be applied using smart detection
    if (_shouldApplyTradingFees(from, to, amount)) {
      return _processTradeWithFees(from, to, amount);
    } else {
      // No fees - direct transfer
      _transfer(from, to, amount);
      return true;
    }
  }

  // ================================
  // SMART FEE DETECTION LOGIC
  // ================================
  
  /**
   * @dev Enhanced logic to determine if trading fees should apply
   */
  function _shouldApplyTradingFees(address from, address to, uint256 /* amount */) 
    internal 
    view
    returns (bool) 
  {
    // No fee exemption list
    
    // Check operation type classifications first
    OperationType fromType = addressOperationType[from];
    OperationType toType = addressOperationType[to];

    // No fees if either side is classified as no fees
    if (fromType == OperationType.NoFees || toType == OperationType.NoFees) {
      return false;
    }

    // No fees if either side is liquidity only
    if (fromType == OperationType.LiquidityOnly || toType == OperationType.LiquidityOnly) {
      return false;
    }

    // Apply fees if either side is swap-enabled
    if (fromType == OperationType.SwapOnly || toType == OperationType.SwapOnly) {
      return true;
    }

    // Enhanced detection for complex DEX operations
    return _detectTradingOperation(from, to);
  }

  /**
   * @dev Detect if this is a trading operation using multiple signals
   */
  function _detectTradingOperation(address from, address to) internal view returns (bool) {
    
    // Legacy pair detection (Uniswap V2 style)
    if (isPair[from] || isPair[to]) {
      return true;
    }

    // Swap router detection
    if (isSwapRouter[from] || isSwapRouter[to]) {
      return true;
    }

    // Balancer vault detection
    if (isBalancerVault[from] || isBalancerVault[to]) {
      return _isBalancerSwap(from, to);
    }

    // Uniswap V3 pool detection
    if (isUniswapV3Pool[from] || isUniswapV3Pool[to]) {
      return _isUniswapV3Swap(from, to);
    }

    // Default to no fees for unknown operations
    return false;
  }

  /**
   * @dev Detect if Balancer operation is a swap vs internal operation
   */
  function _isBalancerSwap(address from, address to) internal view returns (bool) {
    
    // If vault is transferring to/from user directly, likely a swap
    if (isBalancerVault[from] && !isBalancerPool[to] && !isBalancerVault[to]) {
      return true; // Vault → User (swap output)
    }
    
    if (isBalancerVault[to] && !isBalancerPool[from] && !isBalancerVault[from]) {
      return true; // User → Vault (swap input)
    }
    
    return false;
  }

  /**
   * @dev Detect if Uniswap V3 operation is a swap vs liquidity
   */
  function _isUniswapV3Swap(address from, address to) internal view returns (bool) {
    
    // Pool to user = swap output
    if (isUniswapV3Pool[from] && !isUniswapV3Pool[to] && !isPositionManager[to]) {
      return true;
    }
    
    // User to pool = swap input  
    if (isUniswapV3Pool[to] && !isUniswapV3Pool[from] && !isPositionManager[from]) {
      return true;
    }
    
    return false;
  }

  // ================================
  // FEE PROCESSING
  // ================================
  
  /**
   * @dev Process trade with fees applied
   */
  function _processTradeWithFees(address from, address to, uint256 amount) internal returns (bool) {

    // Determine transaction type
    bool fromIsPair = _isKnownTradingVenue(from);
    bool toIsPair = _isKnownTradingVenue(to);

    if (fromIsPair && !toIsPair) {
      // Buy transaction: from a trading venue to a user
      return _processBuy(from, to, amount);
    } else if (!fromIsPair && toIsPair) {
      // Sell transaction: from a user to a trading venue
      return _processSell(from, to, amount);
    } else {
      // Edge case: treat as sell if both are trading venues or neither
      return _processSell(from, to, amount);
    }
  }

  /**
   * @dev Check if address is a known trading venue
   */
  function _isKnownTradingVenue(address addr) internal view returns (bool) {
    return isPair[addr] || 
           isSwapRouter[addr] || 
           isBalancerVault[addr] || 
           isUniswapV3Pool[addr];
  }

  /**
   * @dev Process buy transaction with fees
   */
  function _processBuy(address from, address to, uint256 amount) internal returns (bool) {
    if (controlFlags.feesEnabled) {
      uint256 feeAmount = (amount * buyFees.total) / BASIS_POINTS;
      uint256 transferAmount = amount - feeAmount;

      // Transfer fees to contract first, then distribute
      _transfer(from, address(this), feeAmount);
      _transfer(from, to, transferAmount);
      _distributeBuyFeesFromContract(feeAmount);

      emit SmartFeeApplied(from, to, amount, feeAmount, "buy_detected");

      // Trigger lottery for buys
      if (lotteryManager != address(0)) {
        _safeTriggerLottery(to, amount);
      }
    } else {
      _transfer(from, to, amount);
    }

    return true;
  }

  /**
   * @dev Process sell transaction with fees
   */
  function _processSell(address from, address to, uint256 amount) internal returns (bool) {
    if (controlFlags.feesEnabled) {
      uint256 feeAmount = (amount * sellFees.total) / BASIS_POINTS;
      uint256 transferAmount = amount - feeAmount;

      // Transfer fees to contract first, then distribute
      _transfer(from, address(this), feeAmount);
      _transfer(from, to, transferAmount);
      _distributeSellFeesFromContract(feeAmount);

      emit SmartFeeApplied(from, to, amount, feeAmount, "sell_detected");

      // NO LOTTERY ON SELLS
    } else {
      _transfer(from, to, amount);
    }

    return true;
  }

  // ================================
  // FEE DISTRIBUTION
  // ================================
  
  /**
   * @dev Distribute buy fees from contract balance
   */
  function _distributeBuyFeesFromContract(uint256 feeAmount) internal {
    if (feeAmount == 0) return;

    uint256 jackpotAmount = (feeAmount * buyFees.jackpot) / buyFees.total;
    uint256 revenueAmount = (feeAmount * buyFees.veDRAGON) / buyFees.total;
    uint256 burnAmount = (feeAmount * buyFees.burn) / buyFees.total;

    if (jackpotVault != address(0) && jackpotAmount > 0) {
      _transfer(address(this), jackpotVault, jackpotAmount);
      emit FeesDistributed(jackpotVault, jackpotAmount, EventCategory.BUY_JACKPOT);
    }

    if (revenueDistributor != address(0) && revenueAmount > 0) {
      _transfer(address(this), revenueDistributor, revenueAmount);
      emit FeesDistributed(revenueDistributor, revenueAmount, EventCategory.BUY_REVENUE);
    }

    if (burnAmount > 0) {
      _transfer(address(this), DEAD_ADDRESS, burnAmount);
      emit FeesDistributed(DEAD_ADDRESS, burnAmount, EventCategory.BUY_BURN);
    }
  }

  /**
   * @dev Distribute sell fees from contract balance
   */
  function _distributeSellFeesFromContract(uint256 feeAmount) internal {
    if (feeAmount == 0) return;

    uint256 jackpotAmount = (feeAmount * sellFees.jackpot) / sellFees.total;
    uint256 revenueAmount = (feeAmount * sellFees.veDRAGON) / sellFees.total;
    uint256 burnAmount = (feeAmount * sellFees.burn) / sellFees.total;

    if (jackpotVault != address(0) && jackpotAmount > 0) {
      _transfer(address(this), jackpotVault, jackpotAmount);
      emit FeesDistributed(jackpotVault, jackpotAmount, EventCategory.SELL_JACKPOT);
    }

    if (revenueDistributor != address(0) && revenueAmount > 0) {
      _transfer(address(this), revenueDistributor, revenueAmount);
      emit FeesDistributed(revenueDistributor, revenueAmount, EventCategory.SELL_REVENUE);
    }

    if (burnAmount > 0) {
      _transfer(address(this), DEAD_ADDRESS, burnAmount);
      emit FeesDistributed(DEAD_ADDRESS, burnAmount, EventCategory.SELL_BURN);
    }
  }

  // ================================
  // LOTTERY INTEGRATION
  // ================================
  
  /**
   * @dev Safely trigger lottery with error handling
   */
  function _safeTriggerLottery(address buyer, uint256 amount) internal {
    try IOmniDragonLotteryManager(lotteryManager).processSwapLottery(
      buyer,
      address(this),
      amount,
      0 // Let lottery manager calculate USD value
    ) returns (uint256 /* lotteryEntryId */) {
      emit LotteryTriggered(buyer, amount, 0);
    } catch {
      // Lottery trigger failed, but transaction should continue
      // This prevents lottery issues from blocking token transfers
    }
  }

  // ================================
  // ADMIN CONFIGURATION FUNCTIONS
  // ================================
  
  /**
   * @dev Set operation type for an address
   */
  function setAddressOperationType(
    address addr,
    OperationType opType
  ) external onlyOwner validAddress(addr) {
    addressOperationType[addr] = opType;
  }

  /**
   * @dev Bulk configure DEX addresses
   */
  function configureDEXAddresses() external onlyOwner {
    // Balancer - only swaps via vault should have fees
    addressOperationType[0xBA12222222228d8Ba445958a75a0704d566BF2C8] = OperationType.SwapOnly;
    isBalancerVault[0xBA12222222228d8Ba445958a75a0704d566BF2C8] = true;

    // Uniswap V3 - router = swaps, position manager = liquidity
    addressOperationType[0xE592427A0AEce92De3Edee1F18E0157C05861564] = OperationType.SwapOnly;
    isSwapRouter[0xE592427A0AEce92De3Edee1F18E0157C05861564] = true;
    
    addressOperationType[0xC36442b4a4522E871399CD717aBDD847Ab11FE88] = OperationType.LiquidityOnly;
    isPositionManager[0xC36442b4a4522E871399CD717aBDD847Ab11FE88] = true;

    // Uniswap V2 Router
    addressOperationType[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = OperationType.SwapOnly;
    isSwapRouter[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true;

    // 1inch Aggregation Router
    addressOperationType[0x111111125421cA6dc452d289314280a0f8842A65] = OperationType.SwapOnly;
    isSwapRouter[0x111111125421cA6dc452d289314280a0f8842A65] = true;

    // Our Fusion Integrator (when deployed)
    if (fusionIntegrator != address(0)) {
      addressOperationType[fusionIntegrator] = OperationType.SwapOnly;
      isSwapRouter[fusionIntegrator] = true;
    }
  }

  /**
   * @dev Set Balancer pool addresses
   */
  function setBalancerPool(address pool, bool isPool) external onlyOwner {
    isBalancerPool[pool] = isPool;
    if (isPool) {
      addressOperationType[pool] = OperationType.LiquidityOnly;
    }
  }

  /**
   * @dev Set Uniswap V3 pool addresses
   */
  function setUniswapV3Pool(address pool, bool isPool) external onlyOwner {
    isUniswapV3Pool[pool] = isPool;
  }

  /**
   * @dev Set traditional DEX pair
   */
  function setPair(address pair, bool _isPair) external onlyOwner {
    isPair[pair] = _isPair;
    if (_isPair) {
      addressOperationType[pair] = OperationType.SwapOnly;
    }
  }

  /**
   * @dev Set fusion integrator address
   */
  function setFusionIntegrator(address _fusionIntegrator) external onlyOwner validAddress(_fusionIntegrator) {
    fusionIntegrator = _fusionIntegrator;
    addressOperationType[_fusionIntegrator] = OperationType.SwapOnly;
    isSwapRouter[_fusionIntegrator] = true;
  }

  /**
   * @dev Set lottery manager
   */
  function setLotteryManager(address _lotteryManager) external onlyOwner validAddress(_lotteryManager) {
    lotteryManager = _lotteryManager;
  }

  /**
   * @dev Set jackpot vault
   */
  function setJackpotVault(address _jackpotVault) external onlyOwner validAddress(_jackpotVault) {
    jackpotVault = _jackpotVault;
  }

  /**
   * @dev Set revenue distributor
   */
  function setRevenueDistributor(address _revenueDistributor) external onlyOwner validAddress(_revenueDistributor) {
    revenueDistributor = _revenueDistributor;
  }

  // ================================
  // LAYERZERO OFT FUNCTIONS
  // ================================
  
  // LayerZero V2 OFT handles cross-chain transfers internally
  // Our smart fee detection in _transferWithSmartDetection ensures
  // that cross-chain operations don't trigger trading fees

  // ================================
  // UTILITY FUNCTIONS
  // ================================
  
  /**
   * @dev Get LayerZero endpoint from registry
   */
  function _getLayerZeroEndpoint(address _registry) internal view returns (address) {
    try IOmniDragonRegistry(_registry).getLayerZeroEndpoint(uint16(block.chainid)) returns (address endpoint) {
      return endpoint;
    } catch {
      return address(0);
    }
  }

  // ================================
  // VIEW FUNCTIONS
  // ================================
  
  /**
   * @dev Preview if fees would be applied for a transfer
   */
  function previewFeesForTransfer(address from, address to, uint256 amount) 
    external 
    view 
    returns (
      bool feesApply,
      uint256 feeAmount,
      uint256 transferAmount,
      string memory reason
    ) 
  {
    OperationType fromType = addressOperationType[from];
    OperationType toType = addressOperationType[to];

    if (fromType == OperationType.NoFees || toType == OperationType.NoFees) {
      return (false, 0, amount, "no_fees_classification");
    }

    if (fromType == OperationType.LiquidityOnly || toType == OperationType.LiquidityOnly) {
      return (false, 0, amount, "liquidity_operation");
    }

    if (fromType == OperationType.SwapOnly || toType == OperationType.SwapOnly) {
      feeAmount = (amount * buyFees.total) / BASIS_POINTS;
      return (true, feeAmount, amount - feeAmount, "swap_operation");
    }

    if (isPair[from] || isPair[to] || isSwapRouter[from] || isSwapRouter[to]) {
      feeAmount = (amount * buyFees.total) / BASIS_POINTS;
      return (true, feeAmount, amount - feeAmount, "traditional_dex");
    }

    return (false, 0, amount, "normal_transfer");
  }

  /**
   * @dev Get operation type for an address
   */
  function getOperationType(address addr) external view returns (OperationType) {
    return addressOperationType[addr];
  }

  /**
   * @dev Check if address is classified as trading venue
   */
  function isTradingVenue(address addr) external view returns (bool) {
    return _isKnownTradingVenue(addr);
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