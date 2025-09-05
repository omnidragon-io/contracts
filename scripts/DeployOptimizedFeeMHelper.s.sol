// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/libraries/fees/OptimizedFeeMHelper.sol";

contract DeployOptimizedFeeMHelper is Script {
    function run() external {
        // Load configuration
        address registry = vm.envAddress("REGISTRY_ADDRESS");
        uint256 feeMRegistrationId = 143; // Standard FeeM ID for omniDRAGON
        address jackpotVault = vm.envAddress("JACKPOT_VAULT_ADDRESS");
        address shadowRouter = 0xF5F7231073b3B41c04BA655e1a7438b1a7b29c27; // Shadow Finance router
        
        // Start deployment
        vm.startBroadcast();
        
        // Deploy OptimizedFeeMHelper
        OptimizedFeeMHelper helper = new OptimizedFeeMHelper(
            registry,
            feeMRegistrationId,
            jackpotVault,
            shadowRouter,
            msg.sender // Initial owner
        );
        
        console.log("OptimizedFeeMHelper deployed at:", address(helper));
        
        // Configure the helper
        console.log("Configuring helper...");
        
        // Set initial strategy to PFWS36_DEPOSIT
        helper.setStrategy(OptimizedFeeMHelper.FeeMStrategy.PFWS36_DEPOSIT);
        console.log("Strategy set to PFWS36_DEPOSIT");
        
        // Enable auto-claim with 1 S threshold
        helper.setAutoClaimEnabled(true);
        helper.setAutoClaimThreshold(1 ether);
        console.log("Auto-claim enabled with 1 S threshold");
        
        // Register with FeeM
        helper.registerMe();
        console.log("Registered with FeeM");
        
        vm.stopBroadcast();
        
        // Verify configuration
        console.log("\nConfiguration Summary:");
        console.log("- Registry:", registry);
        console.log("- FeeM Registration ID:", feeMRegistrationId);
        console.log("- Jackpot Vault:", jackpotVault);
        console.log("- Shadow Router:", shadowRouter);
        console.log("- Auto-claim enabled:", helper.autoClaimEnabled());
        console.log("- Auto-claim threshold:", helper.autoClaimThreshold());
        
        (
            OptimizedFeeMHelper.FeeMStrategy strategy,
            uint256 lpAllocation,
            uint256 slippage,
            uint256 totalRevenue,
            uint256 totalPfwS36,
            uint256 totalLP
        ) = helper.getStrategyInfo();
        
        console.log("\nStrategy Info:");
        console.log("- Current Strategy:", uint256(strategy));
        console.log("- LP Allocation BPS:", lpAllocation);
        console.log("- Slippage Tolerance BPS:", slippage);
    }
}
