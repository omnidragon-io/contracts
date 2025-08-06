// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDragonJackpotDistributor
 * @author 0xakita.eth
 * @notice Interface for the Dragon jackpot distribution system
 * @dev Handles prize distribution from jackpot vault to lottery winners
 */
interface IDragonJackpotDistributor {
    /**
     * @notice Distribute jackpot to a winner
     * @param winner Address of the lottery winner
     * @param amount Amount to distribute in DRAGON tokens
     */
    function distributeJackpot(address winner, uint256 amount) external;
    
    /**
     * @notice Get the current jackpot amount available for distribution
     * @return jackpot Current jackpot amount in DRAGON tokens
     */
    function getCurrentJackpot() external view returns (uint256 jackpot);
    
    /**
     * @notice Get the minimum jackpot amount for distribution
     * @return minimum Minimum jackpot amount
     */
    function getMinimumJackpot() external view returns (uint256 minimum);
    
    /**
     * @notice Check if jackpot distribution is currently enabled
     * @return enabled Whether distribution is enabled
     */
    function isDistributionEnabled() external view returns (bool enabled);
    
    /**
     * @notice Get the last distribution timestamp
     * @return timestamp Last distribution time
     */
    function getLastDistributionTime() external view returns (uint256 timestamp);
    
    /**
     * @notice Get total amount distributed to date
     * @return total Total distributed amount
     */
    function getTotalDistributed() external view returns (uint256 total);
    
    /**
     * @notice Get distribution statistics for a specific winner
     * @param winner Winner address
     * @return totalReceived Total amount received by this winner
     * @return distributionCount Number of distributions received
     */
    function getWinnerStats(address winner) external view returns (
        uint256 totalReceived,
        uint256 distributionCount
    );
}