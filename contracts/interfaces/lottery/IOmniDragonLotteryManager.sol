// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOmniDragonLotteryManager
 * @author 0xakita.eth
 * @dev Interface for lottery manager with smart fee detection integration
 */
interface IOmniDragonLotteryManager {
    
    // ================================
    // STRUCTS
    // ================================
    
    struct SwapLotteryEntry {
        address trader;
        address tokenIn;
        uint256 amountIn;
        uint256 swapValueUSD;
        uint256 baseProb;              // Base probability from USD amount
        uint256 veDragonMultiplier;    // veDRAGON multiplier (1x to 2.5x)
        uint256 finalProb;             // Final probability
        uint256 requestId;             // Chainlink VRF request ID
        uint256 randomWord;
        bool fulfilled;
        bool won;
        uint256 prizeAmount;
        uint256 timestamp;
    }
    
    struct UserMilestone {
        uint256 totalVolumeUSD;        // Lifetime trading volume
        uint256 lastUpdated;
        mapping(address => uint256) tokenVolumes;
        mapping(uint256 => uint256) chainVolumes;
    }

    // ================================
    // EVENTS
    // ================================
    
    event SwapLotteryCreated(
        uint256 indexed entryId,
        address indexed trader,
        uint256 swapValueUSD,
        uint256 finalProbability,
        uint256 veDragonMultiplier
    );
    
    event VolumeUpdated(
        address indexed trader,
        uint256 volumeAdded,
        uint256 totalVolume
    );
    
    event LotteryFulfilled(
        uint256 indexed entryId,
        address indexed trader,
        bool won,
        uint256 prizeAmount,
        uint256 randomWord
    );

    // ================================
    // MAIN FUNCTIONS
    // ================================
    
    /**
     * @dev Process swap lottery - handles all lottery logic including USD calculation
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
    ) external returns (uint256 entryId);

    // ================================
    // VIEW FUNCTIONS
    // ================================
    
    /**
     * @dev Preview lottery probability for a potential swap
     */
    function previewSwapLottery(address trader, uint256 swapValueUSD)
        external
        view
        returns (
            uint256 baseProb,
            uint256 veDragonMultiplier,
            uint256 finalProb,
            uint256 probabilityPercent,
            bool isCapped
        );
    
    /**
     * @dev Get user volume statistics
     */
    function getUserVolume(address trader) 
        external 
        view 
        returns (
            uint256 totalVolume,
            uint256 lastUpdated
        );
    
    /**
     * @dev Get detailed probability breakdown for UI
     */
    function getDetailedProbability(address trader, uint256 swapValueUSD)
        external
        view
        returns (
            uint256 baseProbabilityBPS,      // Base prob in basis points
            uint256 veDragonMultiplierBPS,   // veDRAGON multiplier in basis points (10000 = 1x)
            uint256 finalProbabilityBPS,     // Final prob in basis points
            string memory probabilityDisplay, // Human readable "X.XXX%"
            string memory veDragonBoost,     // Human readable "2.3x boost"
            bool isCapped
        );
    
    /**
     * @dev Get lottery entry details
     */
    function getLotteryEntry(uint256 entryId)
        external
        view
        returns (SwapLotteryEntry memory);
    
    /**
     * @dev Get user's current veDRAGON boost level
     */
    function getUserVeDragonBoost(address trader)
        external
        view
        returns (
            uint256 veDragonBalance,
            uint256 multiplier,
            string memory boostDisplay,
            uint256 percentile
        );

    // ================================
    // ADMIN FUNCTIONS
    // ================================
    
    /**
     * @dev Set authorized swap integrator
     */
    function setSwapIntegrator(address integrator, bool authorized) external;
    
    /**
     * @dev Update VRF configuration
     */
    function updateVRFConfig(
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscriptionId
    ) external;
    
    /**
     * @dev Emergency functions
     */
    function emergencyPause() external;
    function emergencyUnpause() external;
}