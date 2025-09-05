// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DragonErrors
 * @author 0xakita.eth
 * @notice Shared custom errors for the Dragon ecosystem
 * @dev Centralizes common error definitions to avoid duplication
 * 
 * Social Links:
 * - Twitter: https://x.com/sonicreddragon
 * - Telegram: https://t.me/sonicreddragon
 */
library DragonErrors {
    // ========== GENERAL ERRORS ==========
    
    /// @dev Thrown when a zero address is passed where it's not allowed
    error ZeroAddress();
    
    /// @dev Thrown when an amount is zero where it's not allowed  
    error ZeroAmount();
    
    /// @dev Thrown when a transfer operation fails
    error TransferFailed();
    
    /// @dev Thrown when there's insufficient balance for an operation
    error InsufficientBalance();
    
    /// @dev Thrown when an unauthorized address attempts an action
    error UnauthorizedCaller();
    
    /// @dev Thrown when a contract is paused
    error ContractPaused();
    
    // ========== VALIDATION ERRORS ==========
    
    /// @dev Thrown when invalid fee structure is provided
    error InvalidFeeStructure();
    
    /// @dev Thrown when invalid fee configuration is set
    error InvalidFeeConfiguration();
    
    /// @dev Thrown when transfer amount exceeds maximum allowed
    error MaxTransferExceeded();
    
    /// @dev Thrown when amount is below minimum threshold
    error AmountBelowMinimum();
    
    // ========== STATE ERRORS ==========
    
    /// @dev Thrown when trading is disabled
    error TradingDisabled();
    
    /// @dev Thrown when emergency mode is disabled but emergency action is attempted
    error EmergencyModeDisabled();
    
    /// @dev Thrown when operation is attempted with no available jackpot
    error NoJackpotToPay();
    
    /// @dev Thrown when wrapped token is not set but required
    error WrappedTokenNotSet();
}