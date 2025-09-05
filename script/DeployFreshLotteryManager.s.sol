// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";

contract DeployFreshLotteryManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING FRESH LOTTERY MANAGER ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID: 146 (Sonic)");
        console.log("");

        // Contract addresses from existing deployments
        address jackpotVault = 0xCd019BD4CB555e2844bB5B1CE625480794601a99; // Placeholder - update if needed
        address veDRAGONToken = 0x69Dc1c36F8B26Db3471ACF0a6469D815E9A27777; // Placeholder - update if needed
        address priceOracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777; // Placeholder - update if needed
        uint256 chainId = 146;

        console.log("Constructor parameters:");
        console.log("  Jackpot Vault:", jackpotVault);
        console.log("  veDRAGON Token:", veDRAGONToken);
        console.log("  Price Oracle:", priceOracle);
        console.log("  Chain ID:", chainId);
        console.log("");

        // Deploy lottery manager
        console.log("Deploying OmniDragonLotteryManager...");
        OmniDragonLotteryManager lotteryManager = new OmniDragonLotteryManager(
            payable(jackpotVault),
            veDRAGONToken,
            payable(priceOracle),
            chainId
        );

        console.log("[SUCCESS] OmniDragonLotteryManager deployed at:", address(lotteryManager));
        console.log("");

        // Configure the lottery
        console.log("Configuring lottery settings...");
        
        // Configure instant lottery: $10 min swap, 69% of jackpot as reward, active, use VRF, enable price updates
        lotteryManager.configureInstantLottery(
            10_000_000,   // minSwapAmount ($10 in 6 decimals)
            6900,         // rewardPercentage (69% of jackpot in basis points)
            true,         // isActive
            true,         // useVRFForInstant
            true          // enablePriceUpdates
        );

        console.log("[SUCCESS] Instant lottery configured");
        console.log("  Min swap amount: $10");
        console.log("  Reward percentage: 69% of jackpot");
        console.log("  Win probability: calculated dynamically based on swap amount");
        console.log("  Active: true");
        console.log("  VRF enabled: true");
        console.log("");

        // Set VRF integrator (from existing deployment)
        address vrfIntegrator = 0x694f00e7CAB26F9D05261c3d62F52a81DE18A777; // Update with actual VRF address
        lotteryManager.setVRFIntegrator(vrfIntegrator);
        console.log("[SUCCESS] VRF integrator set:", vrfIntegrator);
        console.log("");

        // Note: DRAGON token is set via the token contract calling the lottery manager
        console.log("[INFO] DRAGON token will be set when token contract calls lottery manager");
        console.log("");

        // Authorize swap router
        address swapRouter = 0xF5F7231073b3B41c04BA655e1a7438b1a7b29c27; // Update with actual router address
        lotteryManager.setAuthorizedSwapContract(swapRouter, true);
        console.log("[SUCCESS] Swap router authorized:", swapRouter);
        console.log("");

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("New Lottery Manager:", address(lotteryManager));
        console.log("");
        console.log("Next steps:");
        console.log("1. Update DRAGON token to use new lottery manager");
        console.log("2. Fund VRF consumer");
        console.log("3. Test lottery integration");

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT INFO ===");
        console.log("Contract: OmniDragonLotteryManager");
        console.log("Address:", address(lotteryManager));
        console.log("Chain ID: 146");
        console.log("Network: sonic");
        console.log("Deployer:", deployer);
        console.log("Timestamp:", block.timestamp);
    }
}
