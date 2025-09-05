// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDragonJackpotVault
 * @dev Unified interface for the Dragon Jackpot Vault system
 * @notice Combines vault, distribution, and processor functionality
 *
 * Manages jackpot accumulation, distribution, and lottery mechanics
 * Core component of the OmniDragon tokenomics and reward system
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
interface IDragonJackpotVault {
    // ============ Vault Entry Functions ============
    
    /**
     * @dev Enter the jackpot with Dragon tokens
     * @param user Address of the user entering the jackpot
     * @param amount Amount of Dragon tokens to enter
     */
    function enterJackpotWithDragon(address user, uint256 amount) external;

    /**
     * @dev Enter the jackpot with wrapped native tokens
     * @param user Address of the user entering the jackpot
     * @param amount Amount of wrapped native tokens to enter
     */
    function enterJackpotWithWrappedNativeToken(address user, uint256 amount) external;

    /**
     * @dev Enter the jackpot with native tokens
     * @param user Address of the user entering the jackpot
     */
    function enterJackpotWithNative(address user) external payable;
    
    // ============ Jackpot Management Functions ============
    
    /**
     * @dev Add ERC20 tokens to the jackpot with proper token tracking
     * @param token Token address
     * @param amount Amount to add
     */
    function addERC20ToJackpot(address token, uint256 amount) external;

    /**
     * @dev Add collected funds that are already in the vault (for trusted callers only)
     * @param token Token address
     * @param amount Amount to add to accounting
     */
    function addCollectedFunds(address token, uint256 amount) external;
    
    /**
     * @dev Add DRAGON to jackpot manually (alternative to direct transfers)
     * @param amount Amount of omniDRAGON to add
     */
    function addDragonToJackpot(uint256 amount) external;
    
    /**
     * @dev Process any omniDRAGON tokens that were transferred directly to this contract
     */
    function processPendingDragonDeposits() external;
    
    /**
     * @dev Deposit native tokens and convert to pfwS-36
     * @return pfwS36Amount Amount of pfwS-36 shares received
     */
    function depositNativeForPfwS36() external payable returns (uint256 pfwS36Amount);
    
    // ============ Processor Functions ============
    
    /**
     * @notice Deposit and immediately process omniDRAGON
     * @param depositor Address making the deposit
     * @param amount Amount of omniDRAGON to deposit and process
     */
    function depositAndProcess(address depositor, uint256 amount) external;
    
    /**
     * @notice Check if vault supports auto-processing
     */
    function supportsAutoProcessing() external view returns (bool);

    // ============ Distribution Functions ============
    
    /**
     * @notice Pay out jackpot to a winner
     * @param winner Address of the winner
     * @param amount Amount to pay (may be ignored for winner-takes-all)
     */
    function payJackpot(address winner, uint256 amount) external;

    /**
     * @notice Pay ENTIRE jackpot to winner - Winner Takes All!
     * @param winner Winner address who gets everything
     */
    function payEntireJackpot(address winner) external;
    
    /**
     * @notice Distribute jackpot to a winner (alias for payJackpot)
     * @param winner Address of the lottery winner
     * @param amount Amount to distribute
     */
    function distributeJackpot(address winner, uint256 amount) external;

    // ============ View Functions ============
    
    /**
     * @notice Get the current jackpot balance
     * @return balance The current jackpot balance
     */
    function getJackpotBalance() external view returns (uint256 balance);
    
    /**
     * @dev Get jackpot balance for a specific token
     * @param token Token address
     * @return Jackpot balance
     */
    function getJackpotBalance(address token) external view returns (uint256);
    
    /**
     * @notice Get the current jackpot amount available for distribution
     * @return jackpot Current jackpot amount
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
     * @notice Get the time of the last jackpot win
     * @return timestamp The last win timestamp
     */
    function getLastWinTime() external view returns (uint256 timestamp);
    
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
    
    /**
     * @dev Get position breakdown for Peapods strategy
     * @return omniDragon Amount of omniDRAGON tokens
     * @return fatFinger Amount of FatFinger DRAGON tokens
     * @return spDragon Amount of spDRAGON tokens
     * @return peapodsShares Amount of Peapods vault shares
     * @return nativeValue Native token value
     */
    function getPositionBreakdown() external view returns (
        uint256 omniDragon,
        uint256 fatFinger, 
        uint256 spDragon,
        uint256 peapodsShares,
        uint256 nativeValue
    );

    // ============ Configuration Functions ============
    
    /**
     * @notice Set the wrapped native token address
     * @param _wrappedNativeToken The new wrapped native token address
     */
    function setWrappedNativeToken(address _wrappedNativeToken) external;
}