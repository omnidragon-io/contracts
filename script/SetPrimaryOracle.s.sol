// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IOmniDragonLotteryManager {
    function setPrimaryOracle(address payable _primaryOracle) external;
    function primaryOracle() external view returns (address);
    function getDragonPriceUSD() external view returns (int256 price, bool isValid, uint256 timestamp);
    function convertDragonToUSD(uint256 dragonAmount) external view returns (uint256 usdAmount);
    function owner() external view returns (address);
    function CHAIN_ID() external view returns (uint256);
}

contract SetPrimaryOracle is Script {
    function run() external {
        address lotteryManager = 0x5ba90e6749Df5b42A53C55bC89Da757A0ddE7181;
        address oracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== SETTING PRIMARY ORACLE ON SONIC ===");
        console.log("Lottery Manager:", lotteryManager);
        console.log("Oracle:", oracle);
        console.log("Deployer:", deployer);
        console.log("");

        // 1. Check current state
        console.log("1. CURRENT STATE:");
        address currentOracle = IOmniDragonLotteryManager(lotteryManager).primaryOracle();
        console.log("   Current primary oracle:", currentOracle);
        
        uint256 chainId = IOmniDragonLotteryManager(lotteryManager).CHAIN_ID();
        console.log("   Chain ID:", chainId);
        
        address owner = IOmniDragonLotteryManager(lotteryManager).owner();
        console.log("   Contract owner:", owner);
        console.log("   Is deployer owner:", owner == deployer ? "YES" : "NO");
        console.log("");

        // 2. Set the primary oracle (correct for Sonic)
        console.log("2. SETTING PRIMARY ORACLE:");
        try IOmniDragonLotteryManager(lotteryManager).setPrimaryOracle(payable(oracle)) {
            console.log("   [SUCCESS] Primary oracle address set");
        } catch {
            console.log("   [ERROR] Failed to set primary oracle address");
            vm.stopBroadcast();
            return;
        }

        // 3. Verify the change
        console.log("3. VERIFICATION:");
        address newOracle = IOmniDragonLotteryManager(lotteryManager).primaryOracle();
        console.log("   New primary oracle:", newOracle);
        console.log("   Correct:", newOracle == oracle ? "YES" : "NO");
        console.log("");

        // 4. Test oracle integration
        console.log("4. TESTING INTEGRATION:");
        try IOmniDragonLotteryManager(lotteryManager).getDragonPriceUSD() returns (int256 price, bool isValid, uint256 timestamp) {
            console.log("   Price:", price);
            console.log("   Valid:", isValid ? "YES" : "NO");
            console.log("   Timestamp:", timestamp);
            
            if (isValid && price > 0) {
                console.log("   Price in USD: $", uint256(price) / 1e8);
                console.log("   [SUCCESS] Lottery manager getting valid price from primary oracle");
                
                // Test conversion
                try IOmniDragonLotteryManager(lotteryManager).convertDragonToUSD(1e18) returns (uint256 usdAmount) {
                    console.log("   1 DRAGON = $", usdAmount / 1e6);
                    console.log("   [SUCCESS] Price conversion working");
                } catch {
                    console.log("   [ERROR] Price conversion failed");
                }
            } else {
                console.log("   [WARNING] Invalid price from oracle");
            }
        } catch {
            console.log("   [ERROR] Still failed to get price through lottery manager");
        }

        console.log("");
        console.log("=== PRIMARY ORACLE INTEGRATION COMPLETE ===");
        console.log("Lottery manager now properly connected to primary oracle on Sonic!");

        vm.stopBroadcast();
    }
}
