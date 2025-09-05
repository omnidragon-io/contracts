// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOmniDragonRegistry} from "../../interfaces/config/IOmniDragonRegistry.sol";
import {IDragonJackpotVault} from "../../interfaces/lottery/IDragonJackpotVault.sol";
import {DragonErrors} from "../errors/DragonErrors.sol";
import {IRouter} from "../../interfaces/protocols/IRouter.sol";
import {IPeapods} from "../../interfaces/protocols/IPeapods.sol";

/**
 * @title Optimized Dragon FeeM Helper
 * @dev Complete FeeM integration with auto-claim and Peapods yield strategies
 * @notice This is the only FeeM helper contract needed - all functionality in one place
 * 
 * Features:
 * - Sonic FeeM integration with configurable project ID
 * - Auto-claim functionality with threshold
 * - Multiple yield strategies (direct forward, pfwS-36, LP creation)
 * - Chainlink Automation compatible
 * - Emergency recovery functions
 * 
 * Author: OmniDragon Team
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */

// Interfaces
interface IFeeMContract {
    function claimProjectRewards(uint256 projectId) external;
    function getProjectPendingRewards(uint256 projectId) external view returns (uint256);
    function projectOwners(uint256 projectId) external view returns (address);
}

// Use IPeapodsUnified for pfwS-36 vault
// Use IRouterUnified for Shadow Finance router

contract OptimizedFeeMHelper is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant SONIC_CHAIN_ID = 146;
    address public constant SONIC_FEEM_CONTRACT = 0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830;
    IFeeMContract public constant FEEM_CONTRACT = IFeeMContract(0x0B5f073135dF3f5671710F08b08C0c9258aECc35);
    
    // Peapods Strategy Addresses
    address public constant PFWS36_TOKEN = 0x924140B8FA4e609038Be15fB32D4eeFC5ED6DDE0;
    address public constant PDRAGON_TOKEN = 0x3Cf140F598CF8b71deAf41F2E6b12e50Ba3c7FB0;
    address public constant PDRAGON_PFWS36_LP = 0xE1d1f1951e4e501c488d095aC328646B76C39C2b;
    address public constant WRAPPED_SONIC = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    
    // Strategy Configuration
    enum FeeMStrategy {
        DIRECT_FORWARD,    // Send $S directly to vault
        PFWS36_DEPOSIT,    // Convert $S to pfwS-36
        LP_STRATEGY        // Create pDRAGON/pfwS-36 LP positions
    }
    
    // State variables
    IOmniDragonRegistry public immutable registry;
    uint256 public feeMRegistrationId;
    FeeMStrategy public currentStrategy = FeeMStrategy.PFWS36_DEPOSIT;
    uint256 public lpAllocationBps = 5000; // 50% to LP, 50% to direct pfwS-36
    uint256 public slippageTolerance = 300; // 3%
    
    // Auto-claim configuration
    uint256 public autoClaimThreshold = 1 ether; // Auto-claim when > 1S pending
    bool public autoClaimEnabled = true;
    uint256 public lastClaimCheck;
    
    // Contract addresses
    address public jackpotVaultAddress;
    address public shadowRouter;
    IPeapods public pfwS36;
    IRouter public shadowRouterContract;
    
    // Statistics
    uint256 public totalFeeMRevenue;
    uint256 public totalPfwS36Deposits;
    uint256 public totalLPCreated;
    uint256 public lastProcessTime;
    
    // Events
    event FeeMRegistered(uint256 indexed registrationId, bool success);
    event FeeMRevenueReceived(uint256 amount, uint256 timestamp);
    event StrategyChanged(FeeMStrategy oldStrategy, FeeMStrategy newStrategy);
    event PfwS36Deposited(uint256 sAmount, uint256 pfwS36Received, uint256 timestamp);
    event LPPositionCreated(uint256 lpTokens, uint256 pDragonAmount, uint256 pfwS36Amount, uint256 timestamp);
    event DirectForwardExecuted(address indexed vault, uint256 amount, uint256 timestamp);
    event AutoClaimExecuted(uint256 projectId, uint256 amount, uint256 timestamp);
    event AutoClaimThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event AutoClaimToggled(bool enabled);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);
    event ConfigurationUpdated(string parameter, uint256 oldValue, uint256 newValue);
    event ShadowRouterUpdated(address indexed oldRouter, address indexed newRouter);
    event JackpotVaultUpdated(address indexed oldVault, address indexed newVault);
    event RegistrationIdUpdated(uint256 oldId, uint256 newId);

    // Errors
    error NotSonicChain();
    error InvalidStrategy();
    error InvalidSlippage();
    error InvalidAllocation();
    error DepositFailed();
    error SwapFailed();
    error LPCreationFailed();
    error ClaimFailed();
    error NotAuthorized();
    error ThresholdNotMet();

    /**
     * @dev Constructor
     * @param _registry Registry contract address
     * @param _registrationId Initial FeeM registration ID
     * @param _jackpotVault Initial jackpot vault address
     * @param _shadowRouter Shadow Finance router address
     * @param _owner Owner address
     */
    constructor(
        address _registry,
        uint256 _registrationId,
        address _jackpotVault,
        address _shadowRouter,
        address _owner
    ) Ownable(_owner) {
        if (_registry == address(0)) revert DragonErrors.ZeroAddress();
        if (_jackpotVault == address(0)) revert DragonErrors.ZeroAddress();
        if (_shadowRouter == address(0)) revert DragonErrors.ZeroAddress();
        
        // Only deploy on Sonic chain
        if (block.chainid != SONIC_CHAIN_ID) revert NotSonicChain();
        
        registry = IOmniDragonRegistry(_registry);
        feeMRegistrationId = _registrationId;
        jackpotVaultAddress = _jackpotVault;
        shadowRouter = _shadowRouter;
        
        // Initialize Peapods interfaces
        pfwS36 = IPeapods(PFWS36_TOKEN);
        shadowRouterContract = IRouter(_shadowRouter);
        
        emit FeeMRegistered(_registrationId, true);
    }

    // ============ AUTO-CLAIM FUNCTIONS ============

    /**
     * @dev Alternative registration function for FeeM
     */
    function registerMe() external onlyOwner {
        (bool _success,) = SONIC_FEEM_CONTRACT.call(
            abi.encodeWithSignature("selfRegister(uint256)", 143)
        );
        require(_success, "FeeM registration failed");
        
        emit FeeMRegistered(143, _success);
    }

    /**
     * @dev Check pending FeeM rewards for the project
     */
    function getPendingFeeMRewards() external view returns (uint256) {
        try FEEM_CONTRACT.getProjectPendingRewards(feeMRegistrationId) returns (uint256 pending) {
            return pending;
        } catch {
            return 0;
        }
    }

    /**
     * @dev Manually trigger FeeM claim (anyone can call if threshold met)
     */
    function claimFeeMRewards() external {
        if (!autoClaimEnabled) revert NotAuthorized();
        
        uint256 pending = this.getPendingFeeMRewards();
        if (pending < autoClaimThreshold) revert ThresholdNotMet();
        
        _executeClaim();
    }

    /**
     * @dev Owner can force claim regardless of threshold
     */
    function forceClaimFeeMRewards() external onlyOwner {
        _executeClaim();
    }

    /**
     * @dev Execute FeeM claim
     */
    function _executeClaim() internal {
        uint256 balanceBefore = address(this).balance;
        
        try FEEM_CONTRACT.claimProjectRewards(feeMRegistrationId) {
            uint256 balanceAfter = address(this).balance;
            uint256 claimed = balanceAfter - balanceBefore;
            
            lastClaimCheck = block.timestamp;
            emit AutoClaimExecuted(feeMRegistrationId, claimed, block.timestamp);
            
            // Revenue automatically processed by receive() function
        } catch {
            revert ClaimFailed();
        }
    }

    /**
     * @dev Check if claim should be triggered (for automation services)
     */
    function shouldClaim() external view returns (bool) {
        if (!autoClaimEnabled) return false;
        
        uint256 pending = this.getPendingFeeMRewards();
        return pending >= autoClaimThreshold;
    }

    /**
     * @dev Execute claim if conditions are met (for automation)
     */
    function executeClaim() external returns (bool) {
        if (!this.shouldClaim()) return false;
        
        _executeClaim();
        return true;
    }

    // ============ CONFIGURATION FUNCTIONS ============

    /**
     * @dev Update FeeM strategy
     */
    function setStrategy(FeeMStrategy _strategy) external onlyOwner {
        if (uint256(_strategy) > 2) revert InvalidStrategy();
        
        FeeMStrategy oldStrategy = currentStrategy;
        currentStrategy = _strategy;
        
        emit StrategyChanged(oldStrategy, _strategy);
    }

    /**
     * @dev Update LP allocation percentage (only used in LP_STRATEGY)
     */
    function setLPAllocation(uint256 _bps) external onlyOwner {
        if (_bps > 10000) revert InvalidAllocation();
        
        uint256 oldValue = lpAllocationBps;
        lpAllocationBps = _bps;
        
        emit ConfigurationUpdated("lpAllocationBps", oldValue, _bps);
    }

    /**
     * @dev Update slippage tolerance
     */
    function setSlippageTolerance(uint256 _bps) external onlyOwner {
        if (_bps > 1000) revert InvalidSlippage(); // Max 10%
        
        uint256 oldValue = slippageTolerance;
        slippageTolerance = _bps;
        
        emit ConfigurationUpdated("slippageTolerance", oldValue, _bps);
    }

    /**
     * @dev Update auto-claim threshold
     */
    function setAutoClaimThreshold(uint256 _threshold) external onlyOwner {
        uint256 oldThreshold = autoClaimThreshold;
        autoClaimThreshold = _threshold;
        emit AutoClaimThresholdUpdated(oldThreshold, _threshold);
    }

    /**
     * @dev Toggle auto-claim functionality
     */
    function setAutoClaimEnabled(bool _enabled) external onlyOwner {
        autoClaimEnabled = _enabled;
        emit AutoClaimToggled(_enabled);
    }

    /**
     * @dev Update Shadow Finance router address
     */
    function setShadowRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert DragonErrors.ZeroAddress();
        
        address oldRouter = shadowRouter;
        shadowRouter = _router;
        shadowRouterContract = IRouter(_router);
        
        emit ShadowRouterUpdated(oldRouter, _router);
    }

    /**
     * @dev Update jackpot vault address
     */
    function setJackpotVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert DragonErrors.ZeroAddress();
        
        address oldVault = jackpotVaultAddress;
        jackpotVaultAddress = _vault;
        
        emit JackpotVaultUpdated(oldVault, _vault);
    }

    /**
     * @dev Update FeeM registration ID
     */
    function updateFeeMRegistration(uint256 _newId) external onlyOwner {
        uint256 oldId = feeMRegistrationId;
        feeMRegistrationId = _newId;
        emit RegistrationIdUpdated(oldId, _newId);
    }

    // ============ MAIN REVENUE PROCESSING ============

    /**
     * @dev Receive FeeM revenue and process based on current strategy
     */
    receive() external payable nonReentrant {
        if (msg.value > 0) {
            totalFeeMRevenue += msg.value;
            emit FeeMRevenueReceived(msg.value, block.timestamp);
            
            _processRevenue(msg.value);
        }
    }

    /**
     * @dev Manually process accumulated revenue
     */
    function processAccumulatedRevenue() external nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert DragonErrors.InsufficientBalance();
        
        _processRevenue(balance);
    }

    /**
     * @dev Internal function to process revenue based on current strategy
     */
    function _processRevenue(uint256 amount) internal {
        lastProcessTime = block.timestamp;
        
        if (currentStrategy == FeeMStrategy.DIRECT_FORWARD) {
            _directForward(amount);
        } else if (currentStrategy == FeeMStrategy.PFWS36_DEPOSIT) {
            _depositToPfwS36(amount);
        } else if (currentStrategy == FeeMStrategy.LP_STRATEGY) {
            _executeLPStrategy(amount);
        }
    }

    // ============ STRATEGY IMPLEMENTATIONS ============

    /**
     * @dev Strategy 1: Direct forward to vault (original behavior)
     */
    function _directForward(uint256 amount) internal {
        IDragonJackpotVault(jackpotVaultAddress).enterJackpotWithNative{value: amount}(address(this));
        emit DirectForwardExecuted(jackpotVaultAddress, amount, block.timestamp);
    }

    /**
     * @dev Strategy 2: Convert $S to pfwS-36 and send to vault
     */
    function _depositToPfwS36(uint256 amount) internal {
        // Deposit $S to get pfwS-36
        uint256 pfwS36Received = pfwS36.deposit{value: amount}(amount, address(this));
        if (pfwS36Received == 0) revert DepositFailed();
        
        // Send pfwS-36 to vault
        IERC20(PFWS36_TOKEN).safeTransfer(jackpotVaultAddress, pfwS36Received);
        
        totalPfwS36Deposits += amount;
        emit PfwS36Deposited(amount, pfwS36Received, block.timestamp);
    }

    /**
     * @dev Strategy 3: Create pDRAGON/pfwS-36 LP positions
     */
    function _executeLPStrategy(uint256 amount) internal {
        uint256 lpAmount = (amount * lpAllocationBps) / 10000;
        uint256 directAmount = amount - lpAmount;
        
        // Direct deposit portion
        if (directAmount > 0) {
            _depositToPfwS36(directAmount);
        }
        
        // LP creation portion
        if (lpAmount > 0) {
            _createLPPosition(lpAmount);
        }
    }

    /**
     * @dev Create pDRAGON/pfwS-36 LP position
     */
    function _createLPPosition(uint256 sAmount) internal {
        // Split $S: half for pfwS-36, half to swap for pDRAGON
        uint256 halfAmount = sAmount / 2;
        
        // Get pfwS-36
        uint256 pfwS36Amount = pfwS36.deposit{value: halfAmount}(halfAmount, address(this));
        if (pfwS36Amount == 0) revert DepositFailed();
        
        // Swap remaining $S for pDRAGON
        uint256 pDragonAmount = _swapNativeForPDragon(halfAmount);
        if (pDragonAmount == 0) revert SwapFailed();
        
        // Create LP position
        uint256 lpTokens = _createLP(pDragonAmount, pfwS36Amount);
        
        totalLPCreated += sAmount;
        emit LPPositionCreated(lpTokens, pDragonAmount, pfwS36Amount, block.timestamp);
    }

    /**
     * @dev Swap native $S for pDRAGON
     */
    function _swapNativeForPDragon(uint256 sAmount) internal returns (uint256) {
        if (shadowRouter == address(0)) return 0;
        
        // Calculate minimum output with slippage protection
        address[] memory path = new address[](2);
        path[0] = WRAPPED_SONIC;
        path[1] = PDRAGON_TOKEN;
        
        uint256[] memory amountsOut = shadowRouterContract.getAmountsOut(sAmount, path);
        uint256 minOut = (amountsOut[1] * (10000 - slippageTolerance)) / 10000;
        
        uint256[] memory amounts = shadowRouterContract.swapExactETHForTokens{value: sAmount}(
            minOut,
            path,
            address(this),
            block.timestamp + 300
        );
        
        return amounts[1]; // Return pDRAGON amount received
    }

    /**
     * @dev Create LP position with pDRAGON and pfwS-36
     */
    function _createLP(uint256 pDragonAmount, uint256 pfwS36Amount) internal returns (uint256 lpTokens) {
        if (shadowRouter == address(0)) return 0;
        
        // Approve tokens for Shadow router
        IERC20(PDRAGON_TOKEN).forceApprove(shadowRouter, pDragonAmount);
        IERC20(PFWS36_TOKEN).forceApprove(shadowRouter, pfwS36Amount);
        
        // Calculate minimum amounts with slippage protection
        uint256 pDragonMin = (pDragonAmount * (10000 - slippageTolerance)) / 10000;
        uint256 pfwS36Min = (pfwS36Amount * (10000 - slippageTolerance)) / 10000;
        
        // Add liquidity to Shadow's pDRAGON/pfwS-36 pool
        (, , lpTokens) = shadowRouterContract.addLiquidity(
            PDRAGON_TOKEN,
            PFWS36_TOKEN,
            pDragonAmount,
            pfwS36Amount,
            pDragonMin,
            pfwS36Min,
            jackpotVaultAddress, // Send LP tokens to vault
            block.timestamp + 300
        );
        
        // Reset approvals
        IERC20(PDRAGON_TOKEN).forceApprove(shadowRouter, 0);
        IERC20(PFWS36_TOKEN).forceApprove(shadowRouter, 0);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get auto-claim configuration
     */
    function getAutoClaimConfig() external view returns (
        bool enabled,
        uint256 threshold,
        uint256 pending,
        uint256 lastCheck,
        bool shouldExecute
    ) {
        return (
            autoClaimEnabled,
            autoClaimThreshold,
            this.getPendingFeeMRewards(),
            lastClaimCheck,
            this.shouldClaim()
        );
    }

    /**
     * @dev Get current strategy information
     */
    function getStrategyInfo() external view returns (
        FeeMStrategy strategy,
        uint256 lpAllocation,
        uint256 slippage,
        uint256 totalRevenue,
        uint256 totalPfwS36,
        uint256 totalLP
    ) {
        return (
            currentStrategy,
            lpAllocationBps,
            slippageTolerance,
            totalFeeMRevenue,
            totalPfwS36Deposits,
            totalLPCreated
        );
    }

    /**
     * @dev Get comprehensive helper statistics
     */
    function getStats() external view returns (
        uint256 totalRevenue,
        uint256 totalPfwS36,
        uint256 totalLP,
        uint256 pendingBalance,
        uint256 pendingClaim,
        bool autoEnabled,
        uint256 lastProcess
    ) {
        return (
            totalFeeMRevenue,
            totalPfwS36Deposits,
            totalLPCreated,
            address(this).balance,
            this.getPendingFeeMRewards(),
            autoClaimEnabled,
            lastProcessTime
        );
    }

    /**
     * @dev Get expected output amount for a swap (view function)
     */
    function getExpectedSwapOutput(uint256 amountIn, address tokenOut) external view returns (uint256) {
        if (shadowRouter == address(0)) return 0;
        
        address[] memory path = new address[](2);
        path[0] = WRAPPED_SONIC;
        path[1] = tokenOut;
        
        try shadowRouterContract.getAmountsOut(amountIn, path) returns (uint256[] memory amounts) {
            return amounts[1];
        } catch {
            return 0;
        }
    }

    /**
     * @dev Get pfwS-36 balance held by this contract
     */
    function getPfwS36Balance() external view returns (uint256) {
        return IERC20(PFWS36_TOKEN).balanceOf(address(this));
    }

    /**
     * @dev Direct deposit native S to pfwS-36 and forward to vault
     */
    function depositNativeForPfwS36() external payable {
        require(msg.value > 0, "No value sent");
        _depositToPfwS36(msg.value);
    }

    // ============ EMERGENCY FUNCTIONS ============

    /**
     * @dev Emergency withdraw - forward assets to jackpot vault
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // Native token
            uint256 balance = address(this).balance;
            uint256 withdrawAmount = amount == 0 ? balance : amount;
            if (withdrawAmount > balance) revert DragonErrors.InsufficientBalance();
            
            (bool success, ) = payable(jackpotVaultAddress).call{value: withdrawAmount}("");
            if (!success) revert DragonErrors.TransferFailed();
            
            emit EmergencyWithdraw(address(0), withdrawAmount, jackpotVaultAddress);
        } else {
            // ERC20 token
            IERC20 tokenContract = IERC20(token);
            uint256 balance = tokenContract.balanceOf(address(this));
            uint256 withdrawAmount = amount == 0 ? balance : amount;
            if (withdrawAmount > balance) revert DragonErrors.InsufficientBalance();
            
            tokenContract.safeTransfer(jackpotVaultAddress, withdrawAmount);
            emit EmergencyWithdraw(token, withdrawAmount, jackpotVaultAddress);
        }
    }
}