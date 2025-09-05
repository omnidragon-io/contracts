// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IOmniDragonLotteryManager {
    function priceOracle() external view returns (address);
    function getDragonPriceUSD() external view returns (int256 price, bool isValid, uint256 timestamp);
    function convertDragonToUSD(uint256 dragonAmount) external view returns (uint256 usdAmount);
}

interface IOmniDragonOracle {
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
    function updatePrice() external;
    function priceInitialized() external view returns (bool);
    function lastUpdateTime() external view returns (uint256);
}

contract TestOracleIntegration is Script {
    function run() external {
        address lotteryManager = 0x5ba90e6749Df5b42A53C55bC89Da757A0ddE7181;
        address oracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== ORACLE INTEGRATION TEST ===");
        console.log("Lottery Manager:", lotteryManager);
        console.log("Oracle:", oracle);
        console.log("");

        // 1. Check lottery manager's oracle reference
        console.log("1. LOTTERY MANAGER ORACLE CONFIG:");
        try IOmniDragonLotteryManager(lotteryManager).priceOracle() returns (address configuredOracle) {
            console.log("   Configured oracle:", configuredOracle);
            console.log("   Matches expected:", configuredOracle == oracle ? "YES" : "NO");
        } catch {
            console.log("   [ERROR] Failed to get configured oracle");
        }
        console.log("");

        // 2. Check oracle status
        console.log("2. ORACLE STATUS:");
        try IOmniDragonOracle(oracle).priceInitialized() returns (bool initialized) {
            console.log("   Price initialized:", initialized ? "YES" : "NO");
        } catch {
            console.log("   [ERROR] Failed to check if price initialized");
        }

        try IOmniDragonOracle(oracle).lastUpdateTime() returns (uint256 lastUpdate) {
            console.log("   Last update time:", lastUpdate);
            console.log("   Age:", block.timestamp - lastUpdate, "seconds");
            console.log("   Fresh (< 1 hour):", (block.timestamp - lastUpdate) < 3600 ? "YES" : "NO");
        } catch {
            console.log("   [ERROR] Failed to get last update time");
        }
        console.log("");

        // 3. Test direct oracle price fetch
        console.log("3. DIRECT ORACLE PRICE:");
        try IOmniDragonOracle(oracle).getLatestPrice() returns (int256 price, uint256 timestamp) {
            if (price > 0) {
                console.log("   Price: $", uint256(price) / 1e8);
                console.log("   Timestamp:", timestamp);
                console.log("   [SUCCESS] Oracle returning valid price");
            } else {
                console.log("   Price:", price);
                console.log("   [WARNING] Oracle returning zero/negative price");
            }
        } catch {
            console.log("   [ERROR] Failed to get price from oracle");
        }
        console.log("");

        // 4. Test lottery manager's oracle integration
        console.log("4. LOTTERY MANAGER ORACLE INTEGRATION:");
        try IOmniDragonLotteryManager(lotteryManager).getDragonPriceUSD() returns (int256 price, bool isValid, uint256 timestamp) {
            console.log("   Price:", price);
            console.log("   Valid:", isValid ? "YES" : "NO");
            console.log("   Timestamp:", timestamp);
            
            if (isValid && price > 0) {
                console.log("   [SUCCESS] Lottery manager getting valid price");
                
                // Test conversion
                try IOmniDragonLotteryManager(lotteryManager).convertDragonToUSD(1e18) returns (uint256 usdAmount) {
                    console.log("   1 DRAGON = $", usdAmount / 1e6);
                } catch {
                    console.log("   [ERROR] Failed to convert DRAGON to USD");
                }
            } else {
                console.log("   [WARNING] Lottery manager not getting valid price");
            }
        } catch {
            console.log("   [ERROR] Failed to get price through lottery manager");
        }
        console.log("");

        // 5. Try updating oracle price
        console.log("5. ORACLE PRICE UPDATE TEST:");
        try IOmniDragonOracle(oracle).updatePrice() {
            console.log("   [SUCCESS] Oracle price update succeeded");
            
            // Check price again after update
            try IOmniDragonOracle(oracle).getLatestPrice() returns (int256 newPrice, uint256 newTimestamp) {
                console.log("   Updated price: $", uint256(newPrice) / 1e8);
                console.log("   Updated timestamp:", newTimestamp);
            } catch {
                console.log("   [ERROR] Failed to get updated price");
            }
        } catch {
            console.log("   [ERROR] Oracle price update failed");
        }

        console.log("");
        console.log("=== INTEGRATION SUMMARY ===");
        console.log("Next steps if issues found:");
        console.log("1. Ensure oracle is properly initialized");
        console.log("2. Check oracle has valid price data");
        console.log("3. Verify lottery manager oracle address is correct");
        console.log("4. Test price update mechanism");

        vm.stopBroadcast();
    }
}
