// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";

contract DeployFixedLotteryManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING FIXED LOTTERY MANAGER ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID: 146 (Sonic)");
        console.log("");

        // Use correct constructor parameters from current deployments
        address jackpotVault = 0x69eC31A869c537749aF7fD44dD1fD347d62C7777;
        address veDRAGONToken = 0x69F9D14a337823fAD783D21F3669e29088e45777;
        address priceOracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
        uint256 chainId = 146;

        console.log("Constructor parameters:");
        console.log("  Jackpot Vault:", jackpotVault);
        console.log("  veDRAGON Token:", veDRAGONToken);
        console.log("  Price Oracle:", priceOracle);
        console.log("  Chain ID:", chainId);
        console.log("");

        // Deploy fixed lottery manager
        console.log("Deploying FIXED OmniDragonLotteryManager...");
        OmniDragonLotteryManager lotteryManager = new OmniDragonLotteryManager(
            payable(jackpotVault),
            veDRAGONToken,
            payable(priceOracle),
            chainId
        );

        console.log("[SUCCESS] FIXED OmniDragonLotteryManager deployed at:", address(lotteryManager));
        console.log("");

        // Configure the lottery with same settings
        console.log("Configuring lottery settings...");
        lotteryManager.configureInstantLottery(
            10_000_000,   // minSwapAmount ($10 in 6 decimals)
            6900,         // rewardPercentage (69% of jackpot in basis points)
            true,         // isActive
            true,         // useVRFForInstant
            true          // enablePriceUpdates
        );

        console.log("[SUCCESS] Instant lottery configured");
        console.log("");

        // Set primary oracle
        lotteryManager.setPrimaryOracle(payable(priceOracle));
        console.log("[SUCCESS] Primary oracle set");

        // Set VRF integrator
        address vrfIntegrator = 0x694f00e7CAB26F9D05261c3d62F52a81DE18A777;
        lotteryManager.setVRFIntegrator(vrfIntegrator);
        console.log("[SUCCESS] VRF integrator set");

        // Authorize swap router
        address swapRouter = 0xA047e2AbF8263FcA7c368F43e2f960A06FD9949f;
        lotteryManager.setAuthorizedSwapContract(swapRouter, true);
        console.log("[SUCCESS] Swap router authorized");

        console.log("");
        console.log("=== FIXED LOTTERY MANAGER DEPLOYED ===");
        console.log("Address:", address(lotteryManager));
        console.log("");
        console.log("KEY FIX APPLIED:");
        console.log("  USD calculation changed from: (amountIn * price) / 1e18");
        console.log("  To: (amountIn * price) / 1e22");
        console.log("  This correctly handles the oracle's decimal precision");
        console.log("");
        console.log("TESTING NEEDED:");
        console.log("  1. Test USD calculation with real swap amounts");
        console.log("  2. Verify minimum swap threshold works");
        console.log("  3. Test lottery entry creation");

        vm.stopBroadcast();
    }
}
