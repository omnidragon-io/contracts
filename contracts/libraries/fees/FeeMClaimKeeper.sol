// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Simple Chainlink Automation interface (avoiding external dependency)
interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

/**
 * @title FeeM Claim Keeper
 * @dev Chainlink Automation keeper for auto-claiming FeeM rewards
 */

interface IOptimizedFeeMHelper {
    function getPendingFeeMRewards() external view returns (uint256);
    function shouldClaim() external view returns (bool);
    function claimFeeMRewards() external;
    function getAutoClaimConfig() external view returns (bool, uint256, uint256, uint256, bool);
}

contract FeeMClaimKeeper is AutomationCompatibleInterface {
    
    IOptimizedFeeMHelper public immutable feeMHelper;
    address public immutable owner;
    
    // Keeper configuration
    uint256 public checkInterval = 1 hours; // Check every hour
    uint256 public lastCheck;
    uint256 public totalClaims;
    
    // Events
    event ClaimExecuted(uint256 amount, uint256 timestamp);
    event KeeperConfigured(uint256 interval);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _feeMHelper, address _owner) {
        feeMHelper = IOptimizedFeeMHelper(_feeMHelper);
        owner = _owner;
        lastCheck = block.timestamp;
    }

    /**
     * @dev Chainlink Automation check function
     */
    function checkUpkeep(bytes calldata /* checkData */) 
        external 
        view 
        override 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        // Check if enough time has passed
        bool timePassed = (block.timestamp - lastCheck) >= checkInterval;
        
        // Check if claim should be executed
        bool shouldClaim = feeMHelper.shouldClaim();
        
        upkeepNeeded = timePassed && shouldClaim;
        performData = ""; // No additional data needed
    }

    /**
     * @dev Chainlink Automation perform function
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        // Revalidate conditions
        bool timePassed = (block.timestamp - lastCheck) >= checkInterval;
        bool shouldClaim = feeMHelper.shouldClaim();
        
        require(timePassed && shouldClaim, "Conditions not met");
        
        // Execute claim
        uint256 pendingBefore = feeMHelper.getPendingFeeMRewards();
        feeMHelper.claimFeeMRewards();
        
        // Update state
        lastCheck = block.timestamp;
        totalClaims++;
        
        emit ClaimExecuted(pendingBefore, block.timestamp);
    }

    /**
     * @dev Update check interval
     */
    function setCheckInterval(uint256 _interval) external onlyOwner {
        checkInterval = _interval;
        emit KeeperConfigured(_interval);
    }

    /**
     * @dev Get keeper status
     */
    function getKeeperStatus() external view returns (
        uint256 interval,
        uint256 lastCheckTime,
        uint256 nextCheckTime,
        uint256 claims,
        bool readyToClaim
    ) {
        return (
            checkInterval,
            lastCheck,
            lastCheck + checkInterval,
            totalClaims,
            feeMHelper.shouldClaim()
        );
    }
}
