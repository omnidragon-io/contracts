// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOmniDragonLotteryManager} from "../interfaces/lottery/IOmniDragonLotteryManager.sol";

/**
 * @title OmniDragonFusionIntegrator
 * @author 0xakita.eth
 * @dev Integrates 1inch Fusion+ with omniDRAGON lottery system
 * 
 * Features:
 * - Same-chain swaps via 1inch Aggregation Router
 * - Cross-chain swaps via 1inch Fusion+
 * - Automatic lottery entry generation for all swaps
 * - Works with any token pair (not just omniDRAGON)
 * - No additional fees (just 1inch's normal costs)
 * - omniDRAGON fees handled automatically by token contract
 * 
 * User Benefits:
 * - Get 1inch's best rates
 * - Free lottery entries on every swap
 * - Same gas cost as regular 1inch swaps
 * - Cross-chain functionality
 * 
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract OmniDragonFusionIntegrator is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ================================
    // STATE VARIABLES
    // ================================
    
    IOmniDragonLotteryManager public immutable lotteryManager;
    
    // 1inch router addresses (set by admin)
    address public inchAggregationRouter;  // For same-chain swaps
    address public inchFusionRouter;       // For cross-chain swaps
    
    // Platform configuration
    uint256 public platformFee = 0; // No additional fees
    address public feeRecipient;
    
    // omniDRAGON token address for special handling
    address public omniDRAGONToken;
    
    // Swap tracking
    mapping(bytes32 => SwapOrder) public swapOrders;
    mapping(address => uint256) public userSwapCount;
    mapping(address => uint256) public userTotalVolume;

    // ================================
    // STRUCTS & ENUMS
    // ================================
    
    struct SwapOrder {
        address trader;
        address srcToken;
        address dstToken;
        uint256 srcAmount;
        uint256 minDstAmount;
        uint256 actualDstAmount;
        uint256 lotteryEntryId;
        bool completed;
        uint256 timestamp;
        string swapType; // "same_chain" or "cross_chain"
    }

    // ================================
    // EVENTS
    // ================================
    
    event SwapExecuted(
        bytes32 indexed orderId,
        address indexed trader,
        address srcToken,
        address dstToken,
        uint256 srcAmount,
        uint256 dstAmount,
        uint256 lotteryEntryId,
        string swapType
    );

    event FusionSwapInitiated(
        bytes32 indexed orderId,
        address indexed trader,
        uint256 srcChainId,
        uint256 dstChainId,
        uint256 lotteryEntryId
    );

    event LotteryEntryGenerated(
        address indexed trader,
        uint256 indexed entryId,
        address token,
        uint256 amount
    );

    // ================================
    // CONSTRUCTOR
    // ================================
    
    constructor(
        address _lotteryManager,
        address _feeRecipient,
        address _omniDRAGONToken
    ) Ownable(msg.sender) {
        require(_lotteryManager != address(0), "Invalid lottery manager");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_omniDRAGONToken != address(0), "Invalid omniDRAGON token");
        
        lotteryManager = IOmniDragonLotteryManager(_lotteryManager);
        feeRecipient = _feeRecipient;
        omniDRAGONToken = _omniDRAGONToken;
    }

    // ================================
    // MAIN SWAP FUNCTIONS
    // ================================
    
    /**
     * @dev Execute same-chain swap with lottery integration
     * @param srcToken Source token address
     * @param dstToken Destination token address  
     * @param amount Amount to swap
     * @param minReturn Minimum tokens to receive
     * @param swapData Swap calldata from 1inch API
     */
    function executeSwapWithLottery(
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata swapData
    ) external nonReentrant returns (bytes32 orderId, uint256 lotteryEntryId) {
        
        require(amount > 0, "Invalid amount");
        require(srcToken != dstToken, "Same token");
        require(inchAggregationRouter != address(0), "Router not configured");
        
        // Generate order ID
        orderId = _generateOrderId(msg.sender, srcToken, dstToken, amount);
        
        // 1. Transfer tokens from user
        // Note: If srcToken is omniDRAGON, fees will be applied automatically
        IERC20(srcToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // 2. Get actual amount after any fees (for omniDRAGON)
        uint256 actualAmount = IERC20(srcToken).balanceOf(address(this));
        
        // 3. Execute swap via 1inch Aggregation Router
        uint256 dstAmount = _executeAggregationSwap(
            srcToken,
            dstToken, 
            actualAmount,
            minReturn,
            swapData
        );
        
        // 4. Transfer output tokens to user
        // Note: If dstToken is omniDRAGON, fees will be applied automatically
        IERC20(dstToken).safeTransfer(msg.sender, dstAmount);
        
        // 5. Generate lottery entry (using original amount for fairness)
        lotteryEntryId = _generateLotteryEntry(
            msg.sender,
            srcToken,
            amount // Use original amount, not amount after fees
        );
        
        // 6. Record swap
        swapOrders[orderId] = SwapOrder({
            trader: msg.sender,
            srcToken: srcToken,
            dstToken: dstToken,
            srcAmount: amount,
            minDstAmount: minReturn,
            actualDstAmount: dstAmount,
            lotteryEntryId: lotteryEntryId,
            completed: true,
            timestamp: block.timestamp,
            swapType: "same_chain"
        });
        
        // 7. Update user stats
        userSwapCount[msg.sender]++;
        userTotalVolume[msg.sender] += amount;
        
        emit SwapExecuted(
            orderId, 
            msg.sender, 
            srcToken, 
            dstToken, 
            amount, 
            dstAmount, 
            lotteryEntryId,
            "same_chain"
        );
        
        return (orderId, lotteryEntryId);
    }
    
    /**
     * @dev Execute cross-chain swap via 1inch Fusion+
     * @param srcToken Source token address
     * @param dstToken Destination token address (on destination chain)
     * @param amount Amount to swap
     * @param minReturn Minimum tokens to receive
     * @param fusionData Fusion+ order data from 1inch API
     * @param dstChainId Destination chain ID
     */
    function executeFusionSwapWithLottery(
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata fusionData,
        uint256 dstChainId
    ) external nonReentrant returns (bytes32 orderId, uint256 lotteryEntryId) {
        
        require(amount > 0, "Invalid amount");
        require(dstChainId != block.chainid, "Use same-chain swap");
        require(inchFusionRouter != address(0), "Fusion router not configured");
        
        // Generate order ID
        orderId = _generateOrderId(msg.sender, srcToken, dstToken, amount);
        
        // 1. Transfer tokens from user
        // Note: If srcToken is omniDRAGON, fees will be applied automatically
        IERC20(srcToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // 2. Get actual amount after any fees
        uint256 actualAmount = IERC20(srcToken).balanceOf(address(this));
        
        // 3. Generate lottery entry immediately (cross-chain completion tracked separately)
        lotteryEntryId = _generateLotteryEntry(
            msg.sender,
            srcToken,
            amount // Use original amount
        );
        
        // 4. Execute Fusion+ swap
        _executeFusionSwap(srcToken, actualAmount, fusionData);
        
        // 5. Record swap order (completion tracked off-chain)
        swapOrders[orderId] = SwapOrder({
            trader: msg.sender,
            srcToken: srcToken,
            dstToken: dstToken,
            srcAmount: amount,
            minDstAmount: minReturn,
            actualDstAmount: 0, // Will be updated when completed
            lotteryEntryId: lotteryEntryId,
            completed: false,
            timestamp: block.timestamp,
            swapType: "cross_chain"
        });
        
        // 6. Update user stats
        userSwapCount[msg.sender]++;
        userTotalVolume[msg.sender] += amount;
        
        emit FusionSwapInitiated(
            orderId, 
            msg.sender, 
            block.chainid, 
            dstChainId, 
            lotteryEntryId
        );
        
        return (orderId, lotteryEntryId);
    }

    // ================================
    // INTERNAL FUNCTIONS
    // ================================
    
    /**
     * @dev Execute swap via 1inch Aggregation Router
     */
    function _executeAggregationSwap(
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata swapData
    ) internal returns (uint256 dstAmount) {
        
        // Approve tokens to 1inch router
        IERC20(srcToken).safeIncreaseAllowance(inchAggregationRouter, amount);
        
        // Get balance before swap
        uint256 balanceBefore = IERC20(dstToken).balanceOf(address(this));
        
        // Execute swap via 1inch
        (bool success, ) = inchAggregationRouter.call(swapData);
        require(success, "1inch swap failed");
        
        // Calculate received amount
        uint256 balanceAfter = IERC20(dstToken).balanceOf(address(this));
        dstAmount = balanceAfter - balanceBefore;
        
        require(dstAmount >= minReturn, "Insufficient output amount");
        
        return dstAmount;
    }
    
    /**
     * @dev Execute cross-chain swap via 1inch Fusion+
     */
    function _executeFusionSwap(
        address srcToken,
        uint256 amount,
        bytes calldata fusionData
    ) internal {
        
        // Approve tokens to Fusion router
        IERC20(srcToken).safeIncreaseAllowance(inchFusionRouter, amount);
        
        // Execute Fusion+ order
        (bool success, ) = inchFusionRouter.call(fusionData);
        require(success, "Fusion+ swap failed");
    }
    
    /**
     * @dev Generate lottery entry for the swap
     */
    function _generateLotteryEntry(
        address user,
        address token,
        uint256 amount
    ) internal returns (uint256 lotteryEntryId) {
        
        try lotteryManager.processSwapLottery(
            user,
            token,
            amount,
            0 // Let lottery manager calculate USD value
        ) returns (uint256 entryId) {
            
            emit LotteryEntryGenerated(user, entryId, token, amount);
            return entryId;
            
        } catch {
            // Lottery generation failed, but swap should continue
            // Return 0 to indicate no lottery entry was created
            return 0;
        }
    }
    
    /**
     * @dev Generate unique order ID
     */
    function _generateOrderId(
        address trader,
        address srcToken,
        address dstToken,
        uint256 amount
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            trader,
            srcToken,
            dstToken,
            amount,
            block.timestamp,
            block.number,
            userSwapCount[trader]
        ));
    }

    // ================================
    // VIEW FUNCTIONS
    // ================================
    
    /**
     * @dev Get swap order details
     */
    function getSwapOrder(bytes32 orderId) 
        external 
        view 
        returns (SwapOrder memory) 
    {
        return swapOrders[orderId];
    }
    
    /**
     * @dev Get user's swap statistics
     */
    function getUserStats(address user) 
        external 
        view 
        returns (
            uint256 totalSwaps, 
            uint256 totalVolume,
            uint256 lastSwapTime
        ) 
    {
        totalSwaps = userSwapCount[user];
        totalVolume = userTotalVolume[user];
        
        // Find last swap time (simplified - in production might want to track this separately)
        lastSwapTime = 0;
        // Could implement by tracking user's order IDs
    }

    /**
     * @dev Preview swap execution (for frontend)
     */
    function previewSwap(
        address user,
        address srcToken,
        uint256 amount
    ) external view returns (
        bool willGenerateLottery,
        uint256 estimatedFees,
        string memory feeReason
    ) {
        
        willGenerateLottery = true; // All swaps generate lottery entries
        
        // Check if omniDRAGON is involved (fees would be applied by token contract)
        if (srcToken == omniDRAGONToken) {
            estimatedFees = (amount * 1000) / 10000; // 10% fee
            feeReason = "omniDRAGON_token_fee";
        } else {
            estimatedFees = 0;
            feeReason = "no_additional_fees";
        }
        
        return (willGenerateLottery, estimatedFees, feeReason);
    }

    // ================================
    // ADMIN FUNCTIONS
    // ================================
    
    /**
     * @dev Set 1inch router addresses
     */
    function setRouterAddresses(
        address _aggregationRouter,
        address _fusionRouter
    ) external onlyOwner {
        require(_aggregationRouter != address(0), "Invalid aggregation router");
        require(_fusionRouter != address(0), "Invalid fusion router");
        
        inchAggregationRouter = _aggregationRouter;
        inchFusionRouter = _fusionRouter;
    }
    
    /**
     * @dev Update platform fee (emergency only)
     */
    function setPlatformFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100, "Fee too high"); // Max 1%
        platformFee = _fee;
    }
    
    /**
     * @dev Update omniDRAGON token address
     */
    function setOmniDRAGONToken(address _omniDRAGONToken) external onlyOwner {
        require(_omniDRAGONToken != address(0), "Invalid omniDRAGON token");
        omniDRAGONToken = _omniDRAGONToken;
    }
    
    /**
     * @dev Update order status (for cross-chain tracking)
     */
    function updateOrderStatus(
        bytes32 orderId, 
        uint256 actualDstAmount,
        bool completed
    ) external onlyOwner {
        
        SwapOrder storage order = swapOrders[orderId];
        require(order.trader != address(0), "Order not found");
        
        order.actualDstAmount = actualDstAmount;
        order.completed = completed;
    }
    
    /**
     * @dev Emergency token recovery for non-core tokens only. Disallow withdrawing omniDRAGON token for optics.
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != omniDRAGONToken, "Cannot withdraw omniDRAGON");
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    /**
     * @dev Emergency pause (withdraw all tokens)
     */
    function emergencyPause() external onlyOwner {
        // This contract should never hold tokens for extended periods
        // Any tokens here are likely from failed swaps or fees
        
        // Could implement a more sophisticated pause mechanism if needed
        revert("Use emergencyWithdraw for specific tokens");
    }

    // ================================
    // INTEGRATION HELPERS
    // ================================
    
    /**
     * @dev Batch execute multiple swaps (gas optimization)
     */
    function batchExecuteSwaps(
        address[] calldata srcTokens,
        address[] calldata dstTokens,
        uint256[] calldata amounts,
        uint256[] calldata minReturns,
        bytes[] calldata swapDatas
    ) external nonReentrant returns (
        bytes32[] memory orderIds,
        uint256[] memory lotteryEntryIds
    ) {
        
        require(srcTokens.length == dstTokens.length, "Array length mismatch");
        require(srcTokens.length == amounts.length, "Array length mismatch");
        require(srcTokens.length == minReturns.length, "Array length mismatch");
        require(srcTokens.length == swapDatas.length, "Array length mismatch");
        require(srcTokens.length <= 10, "Too many swaps"); // Prevent gas issues
        
        orderIds = new bytes32[](srcTokens.length);
        lotteryEntryIds = new uint256[](srcTokens.length);
        
        for (uint256 i = 0; i < srcTokens.length; i++) {
            (orderIds[i], lotteryEntryIds[i]) = this.executeSwapWithLottery(
                srcTokens[i],
                dstTokens[i],
                amounts[i],
                minReturns[i],
                swapDatas[i]
            );
        }
        
        return (orderIds, lotteryEntryIds);
    }

    /**
     * @dev Receive ETH for native token swaps
     */
    receive() external payable {
        // Allow receiving ETH for native token swaps
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

    /**
     * @dev Fallback function
     */
    fallback() external payable {
        revert("Function not found");
    }
}