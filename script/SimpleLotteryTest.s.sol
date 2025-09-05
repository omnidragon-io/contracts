// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IOmniDragonLotteryManager {
    function getInstantLotteryConfig() external view returns (uint256, uint256, bool, bool, bool);
    function totalLotteryEntries() external view returns (uint256);
    function priceOracle() external view returns (address);
    function vrfIntegrator() external view returns (address);
}

interface IOmniDragonPriceOracle {
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
}

contract SimpleLotteryTest is Script {
    function run() external {
        address lotteryManager = 0x5ba90e6749Df5b42A53C55bC89Da757A0ddE7181;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== SIMPLE LOTTERY INTEGRATION TEST ===");
        console.log("Deployer:", deployer);
        console.log("");

        // Check lottery status
        console.log("1. LOTTERY STATUS:");
        (uint256 minSwapUSD, uint256 rewardPercentage, bool isActive, bool useVRF, bool enablePrice) =
            IOmniDragonLotteryManager(lotteryManager).getInstantLotteryConfig();

        console.log("   Active:", isActive ? "YES" : "NO");
        console.log("   VRF enabled:", useVRF ? "YES" : "NO");
        console.log("   Price updates:", enablePrice ? "YES" : "NO");
        console.log("   Min swap USD (wei):", minSwapUSD);
        console.log("   Reward percentage:", rewardPercentage);
        console.log("");

        // Check contracts
        console.log("2. CONTRACT STATUS:");
        address priceOracleAddr = IOmniDragonLotteryManager(lotteryManager).priceOracle();
        address vrfIntegratorAddr = IOmniDragonLotteryManager(lotteryManager).vrfIntegrator();

        console.log("   Price oracle:", priceOracleAddr);
        console.log("   VRF integrator:", vrfIntegratorAddr);
        console.log("");

        // Check price
        console.log("3. PRICE ORACLE:");
        if (priceOracleAddr != address(0)) {
            try IOmniDragonPriceOracle(priceOracleAddr).getLatestPrice() returns (int256 price, uint256 timestamp) {
                console.log("   Price: $", uint256(price) / 1e8);
                console.log("   Timestamp:", timestamp);
                console.log("   Age:", block.timestamp - timestamp, "seconds");
                console.log("   Fresh:", (block.timestamp - timestamp) < 3600 ? "YES" : "NO");
            } catch {
                console.log("   Price fetch failed");
            }
        } else {
            console.log("   No price oracle set");
        }
        console.log("");

        // Summary
        console.log("4. SUMMARY:");
        uint256 entries = IOmniDragonLotteryManager(lotteryManager).totalLotteryEntries();
        console.log("   Current lottery entries:", entries);

        bool lotteryReady = isActive && useVRF && priceOracleAddr != address(0) && vrfIntegratorAddr != address(0);
        console.log("   Lottery system ready:", lotteryReady ? "YES" : "NO");

        if (lotteryReady) {
            console.log("");
            console.log("   [SUCCESS] Lottery system is operational!");
            console.log("   [SUCCESS] Ready to process swaps > $10");
            console.log("   [SUCCESS] VRF integration enabled");
        } else {
            console.log("");
            console.log("   [WARNING] Lottery system not ready");
            if (!isActive) console.log("   - Lottery not active");
            if (!useVRF) console.log("   - VRF not enabled");
            if (priceOracleAddr == address(0)) console.log("   - No price oracle");
            if (vrfIntegratorAddr == address(0)) console.log("   - No VRF integrator");
        }

        vm.stopBroadcast();
    }
}
