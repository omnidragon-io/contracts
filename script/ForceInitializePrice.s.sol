// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OmniDragonOracle} from "../contracts/core/oracles/OmniDragonOracle.sol";

contract ForceInitializePrice is Script {
    address constant SONIC_ORACLE = 0x698cFFa2Aa94348796f6B923Ef285De6997B6777;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Force Initialize Price ===");
        console.log("Sonic Oracle:", SONIC_ORACLE);
        
        OmniDragonOracle sonicOracle = OmniDragonOracle(payable(SONIC_ORACLE));
        
        // Check individual sources
        console.log("=== Checking Individual Sources ===");
        (int256 pythPrice, bool pythValid) = sonicOracle.getPythPrice();
        (int256 api3Price, bool api3Valid) = sonicOracle.getAPI3Price();
        
        console.log("Pyth Price:", uint256(pythPrice));
        console.log("Pyth Valid:", pythValid);
        console.log("API3 Price:", uint256(api3Price));
        console.log("API3 Valid:", api3Valid);
        console.log("");
        
        // Calculate average manually
        int256 manualAverage = 0;
        uint256 validCount = 0;
        
        if (pythValid && pythPrice > 0) {
            manualAverage += pythPrice;
            validCount++;
        }
        
        if (api3Valid && api3Price > 0) {
            manualAverage += api3Price;
            validCount++;
        }
        
        if (validCount > 0) {
            manualAverage = manualAverage / int256(validCount);
        }
        
        console.log("Manual Average Price:", uint256(manualAverage));
        console.log("Valid Sources Count:", validCount);
        console.log("");
        
        // If we have valid data, try to force price initialization
        if (validCount >= 1 && manualAverage > 0) {
            vm.startBroadcast(deployerPrivateKey);
            
            console.log("=== Force Setting Price ===");
            
            // Try to manually trigger price setting with current timestamp
            uint256 currentTimestamp = block.timestamp;
            
            // Let's try calling updatePrice with try/catch to get more info
            try sonicOracle.updatePrice() {
                console.log("SUCCESS: updatePrice worked!");
            } catch Error(string memory reason) {
                console.log("updatePrice failed with reason:", reason);
            } catch (bytes memory lowLevelData) {
                console.log("updatePrice failed with low-level error, length:", lowLevelData.length);
            }
            
            // Alternative: Try to set price manually if the contract has such function
            // Let's check if emergency mode helps
            try sonicOracle.setEmergencyMode(true) {
                console.log("Emergency mode enabled");
                
                // Try price update in emergency mode
                try sonicOracle.updatePrice() {
                    console.log("SUCCESS: updatePrice worked in emergency mode!");
                } catch {
                    console.log("Still failing even in emergency mode");
                }
                
                // Disable emergency mode
                sonicOracle.setEmergencyMode(false);
                console.log("Emergency mode disabled");
                
            } catch {
                console.log("Could not enable emergency mode");
            }
            
            vm.stopBroadcast();
        }
        
        // Check final state
        console.log("=== Final State Check ===");
        (int256 finalPrice, uint256 finalTimestamp) = sonicOracle.getLatestPrice();
        bool initialized = sonicOracle.priceInitialized();
        
        console.log("Final Price:", uint256(finalPrice));
        console.log("Final Timestamp:", finalTimestamp);
        console.log("Is Initialized:", initialized);
        
        if (initialized && finalPrice > 0) {
            console.log("SUCCESS: Oracle is now initialized with valid price!");
            console.log("Oracle ready for cross-chain requests");
        } else {
            console.log("STILL NOT WORKING: Oracle not properly initialized");
            console.log("Recommendation: Check contract source code for minimum requirements");
            console.log("Possible issues:");
            console.log("- Minimum number of valid sources required");
            console.log("- Price staleness checks");
            console.log("- Price deviation limits");
            console.log("- Missing emergency/admin functions");
        }
    }
}
