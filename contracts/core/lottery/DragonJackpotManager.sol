// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DragonJackpotManager
 * @author 0xakita.eth
 * @notice Automated manager for converting pDRAGON → ffDRAGON → wS
 * @dev Works with DragonJackpotVault to maintain wS liquidity
 *
 * Key features:
 * - Monitors vault's pDRAGON balance and wS needs
 * - Executes efficient swaps through configured DEX routers
 * - Supports multiple DEX protocols (Uniswap V2, Solidly forks)
 * - Configurable thresholds and slippage protection
 * - Gas-efficient batch operations
 *
 * Note: Uses ffDRAGON (FatFinger DRAGON) at 0x40f531123bce8962D9ceA52a3B150023bef488Ed
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IDragonJackpotVault {
    function redeemPDragonToDragon(uint256 shares) external;
    function pullDragonToUnwinder(uint256 amount) external;
    function getRawBalances() external view returns (uint256 wsDirect, uint256 pfwShares, uint256 drgDirect, uint256 pdrgShares);
    function getJackpotBalance() external view returns (uint256);
}

interface IERC4626 {
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
}

interface IRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external view returns (uint256[] memory amounts);
}

contract DragonJackpotManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---- Configuration
    struct UnwindConfig {
        uint256 minWsReserve;        // Minimum wS to maintain in vault (e.g., 1000e18)
        uint256 targetWsReserve;     // Target wS reserve after unwind (e.g., 5000e18)
        uint256 minUnwindAmount;     // Minimum DRAGON to unwind (gas efficiency)
        uint256 maxSlippageBps;      // Max slippage in basis points (e.g., 300 = 3%)
        bool autoUnwindEnabled;      // Whether auto-unwind is active
    }

    // ---- State
    IDragonJackpotVault public immutable vault;
    IERC20 public immutable wS;
    IERC20 public immutable ffDRAGON;  // FatFinger DRAGON token
    IERC20 public immutable pDRAGON;
    
    IRouter public router;
    address[] public ffDragonToWsPath;  // Path from ffDRAGON to wS
    UnwindConfig public config;
    
    mapping(address => bool) public keepers;
    
    // ---- Events
    event UnwindExecuted(uint256 dragonAmount, uint256 wsReceived);
    event ConfigUpdated(UnwindConfig newConfig);
    event RouterUpdated(address indexed oldRouter, address indexed newRouter);
    event PathUpdated(address[] newPath);
    event KeeperUpdated(address indexed keeper, bool authorized);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    
    // ---- Errors
    error NotKeeper();
    error InvalidConfig();
    error UnwindNotNeeded();
    error InsufficientDragon();
    error SlippageExceeded();
    error SwapFailed();
    
    modifier onlyKeeper() {
        if (!keepers[msg.sender] && msg.sender != owner()) revert NotKeeper();
        _;
    }
    
    constructor(
        address _vault,
        address _wS,
        address _ffDRAGON,
        address _pDRAGON,
        address _router
    ) Ownable(msg.sender) {
        vault = IDragonJackpotVault(_vault);
        wS = IERC20(_wS);
        ffDRAGON = IERC20(_ffDRAGON);
        pDRAGON = IERC20(_pDRAGON);
        router = IRouter(_router);
        
        // Default configuration
        config = UnwindConfig({
            minWsReserve: 1000e18,      // 1000 wS minimum
            targetWsReserve: 5000e18,    // 5000 wS target
            minUnwindAmount: 100e18,     // 100 ffDRAGON minimum
            maxSlippageBps: 300,         // 3% max slippage
            autoUnwindEnabled: true
        });
        
        // Default path: ffDRAGON -> wS (direct)
        ffDragonToWsPath = new address[](2);
        ffDragonToWsPath[0] = _ffDRAGON;
        ffDragonToWsPath[1] = _wS;
    }
    
    // ---- Keeper Functions ----
    
    /**
     * @notice Check if unwind is needed based on vault's wS balance
     * @return needed Whether unwind is needed
     * @return dragonAmount Amount of DRAGON to unwind
     */
    function isUnwindNeeded() public view returns (bool needed, uint256 dragonAmount) {
        if (!config.autoUnwindEnabled) return (false, 0);
        
        (uint256 wsDirect, , uint256 dragonDirect, uint256 pDragonShares) = vault.getRawBalances();
        
        // Check if wS is below minimum
        if (wsDirect >= config.minWsReserve) return (false, 0);
        
        // Calculate how much wS we need
        uint256 wsNeeded = config.targetWsReserve - wsDirect;
        
        // Check available DRAGON (direct + from pDRAGON)
        uint256 availableDragon = dragonDirect;
        if (pDragonShares > 0) {
            try IERC4626(address(pDRAGON)).convertToAssets(pDragonShares) returns (uint256 assets) {
                availableDragon += assets;
            } catch {
                // If preview fails, use direct DRAGON only
            }
        }
        
        if (availableDragon == 0) return (false, 0);
        
        // Estimate DRAGON needed for target wS
        try router.getAmountsOut(wsNeeded, _reversePath()) returns (uint256[] memory amounts) {
            dragonAmount = amounts[1]; // Amount of DRAGON needed
            
            // Cap at available amount
            if (dragonAmount > availableDragon) {
                dragonAmount = availableDragon;
            }
            
            // Check minimum threshold
            if (dragonAmount < config.minUnwindAmount) {
                return (false, 0);
            }
            
            return (true, dragonAmount);
        } catch {
            // If quote fails, try with all available DRAGON
            if (availableDragon >= config.minUnwindAmount) {
                return (true, availableDragon);
            }
            return (false, 0);
        }
    }
    
    /**
     * @notice Execute unwind operation
     * @param maxDragonAmount Maximum DRAGON to unwind (0 = auto-calculate)
     */
    function executeUnwind(uint256 maxDragonAmount) external onlyKeeper nonReentrant {
        (bool needed, uint256 dragonAmount) = isUnwindNeeded();
        if (!needed) revert UnwindNotNeeded();
        
        // Cap at max if specified
        if (maxDragonAmount > 0 && dragonAmount > maxDragonAmount) {
            dragonAmount = maxDragonAmount;
        }
        
        // Get current balances
        (, , uint256 dragonInVault, uint256 pDragonShares) = vault.getRawBalances();
        
        // First, redeem pDRAGON if needed
        if (dragonAmount > dragonInVault && pDragonShares > 0) {
            uint256 dragonNeeded = dragonAmount - dragonInVault;
            
            // Calculate shares to redeem
            uint256 sharesToRedeem = _calculateSharesForAssets(dragonNeeded, pDragonShares);
            
            if (sharesToRedeem > 0) {
                vault.redeemPDragonToDragon(sharesToRedeem);
            }
        }
        
        // Pull ffDRAGON from vault
        uint256 ffDragonBalance = ffDRAGON.balanceOf(address(this));
        uint256 ffDragonToPull = dragonAmount > ffDragonBalance ? dragonAmount - ffDragonBalance : 0;
        
        if (ffDragonToPull > 0) {
            vault.pullDragonToUnwinder(ffDragonToPull);
        }
        
        // Update actual amount
        dragonAmount = ffDRAGON.balanceOf(address(this));
        if (dragonAmount < config.minUnwindAmount) revert InsufficientDragon();
        
        // Execute swap
        uint256 wsReceived = _swapDragonForWs(dragonAmount);
        
        // Send wS back to vault
        wS.safeTransfer(address(vault), wsReceived);
        
        emit UnwindExecuted(dragonAmount, wsReceived);
    }
    
    /**
     * @notice Manual unwind with specific amounts
     * @param pDragonShares Amount of pDRAGON shares to redeem
     * @param dragonAmount Amount of DRAGON to pull and swap
     */
    function manualUnwind(uint256 pDragonShares, uint256 dragonAmount) external onlyKeeper nonReentrant {
        // Redeem pDRAGON if specified
        if (pDragonShares > 0) {
            vault.redeemPDragonToDragon(pDragonShares);
        }
        
        // Pull DRAGON if specified
        if (dragonAmount > 0) {
            vault.pullDragonToUnwinder(dragonAmount);
        }
        
        // Swap all ffDRAGON balance
        uint256 ffDragonBalance = ffDRAGON.balanceOf(address(this));
        if (ffDragonBalance > 0) {
            uint256 wsReceived = _swapDragonForWs(ffDragonBalance);
            wS.safeTransfer(address(vault), wsReceived);
            emit UnwindExecuted(ffDragonBalance, wsReceived);
        }
    }
    
    // ---- Internal Functions ----
    
    function _swapDragonForWs(uint256 ffDragonAmount) internal returns (uint256) {
        // Get expected output
        uint256[] memory amounts = router.getAmountsOut(ffDragonAmount, ffDragonToWsPath);
        uint256 expectedWs = amounts[amounts.length - 1];
        
        // Calculate minimum with slippage
        uint256 minWs = (expectedWs * (10000 - config.maxSlippageBps)) / 10000;
        
        // Approve router
        ffDRAGON.approve(address(router), ffDragonAmount);
        
        // Execute swap
        uint256 balanceBefore = wS.balanceOf(address(this));
        
        try router.swapExactTokensForTokens(
            ffDragonAmount,
            minWs,
            ffDragonToWsPath,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        ) returns (uint256[] memory) {
            uint256 received = wS.balanceOf(address(this)) - balanceBefore;
            
            // Reset approval
            ffDRAGON.approve(address(router), 0);
            
            return received;
        } catch {
            // Reset approval on failure
            ffDRAGON.approve(address(router), 0);
            revert SwapFailed();
        }
    }
    
    function _calculateSharesForAssets(uint256 assets, uint256 maxShares) internal view returns (uint256) {
        try IERC4626(address(pDRAGON)).convertToAssets(maxShares) returns (uint256 maxAssets) {
            if (assets >= maxAssets) {
                return maxShares;
            }
            // Approximate shares needed (may be slightly off due to rounding)
            return (assets * maxShares) / maxAssets;
        } catch {
            return 0;
        }
    }
    
    function _reversePath() internal view returns (address[] memory) {
        address[] memory reversed = new address[](ffDragonToWsPath.length);
        for (uint256 i = 0; i < ffDragonToWsPath.length; i++) {
            reversed[i] = ffDragonToWsPath[ffDragonToWsPath.length - 1 - i];
        }
        return reversed;
    }
    
    // ---- Admin Functions ----
    
    function updateConfig(UnwindConfig calldata _config) external onlyOwner {
        if (_config.maxSlippageBps > 1000) revert InvalidConfig(); // Max 10% slippage
        if (_config.targetWsReserve < _config.minWsReserve) revert InvalidConfig();
        
        config = _config;
        emit ConfigUpdated(_config);
    }
    
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router");
        address oldRouter = address(router);
        router = IRouter(_router);
        emit RouterUpdated(oldRouter, _router);
    }
    
    function setSwapPath(address[] calldata _path) external onlyOwner {
        require(_path.length >= 2, "Invalid path");
        require(_path[0] == address(ffDRAGON), "Path must start with ffDRAGON");
        require(_path[_path.length - 1] == address(wS), "Path must end with wS");
        
        ffDragonToWsPath = _path;
        emit PathUpdated(_path);
    }
    
    function setKeeper(address keeper, bool authorized) external onlyOwner {
        keepers[keeper] = authorized;
        emit KeeperUpdated(keeper, authorized);
    }
    
    // ---- Emergency Functions ----
    
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(owner(), balance);
            emit EmergencyWithdraw(token, balance);
        }
    }
    
    // ---- View Functions ----
    
    function getUnwindStatus() external view returns (
        bool needed,
        uint256 dragonToUnwind,
        uint256 expectedWsOutput,
        uint256 currentWsBalance,
        uint256 targetWsBalance
    ) {
        (needed, dragonToUnwind) = isUnwindNeeded();
        (currentWsBalance, , , ) = vault.getRawBalances();
        targetWsBalance = config.targetWsReserve;
        
        if (dragonToUnwind > 0) {
            try router.getAmountsOut(dragonToUnwind, ffDragonToWsPath) returns (uint256[] memory amounts) {
                expectedWsOutput = amounts[amounts.length - 1];
            } catch {
                expectedWsOutput = 0;
            }
        }
    }
}
