// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IOmniDragonOracle {
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
}

interface IOmniDragonLotteryManager {
    function primaryOracle() external view returns (address);
    function instantLotteryConfig() external view returns (uint256, uint256, bool, bool, bool);
}

contract TestLotteryManagerLogic is Script {
    function run() external {
        address lotteryManager = 0xCb6F1863672a01e0A4fF321501bbf7bA705F1838;
        
        console.logString("=== TESTING LOTTERY MANAGER LOGIC ===");
        
        // Get the primary oracle from lottery manager
        address primaryOracleAddr = IOmniDragonLotteryManager(lotteryManager).primaryOracle();
        console.logString("Primary oracle from LM:");
        console.logAddress(primaryOracleAddr);
        
        // Test the oracle call exactly like the lottery manager does
        IOmniDragonOracle primaryOracle = IOmniDragonOracle(primaryOracleAddr);
        
        console.logString("Testing _getOraclePrice logic...");
        
        if (address(primaryOracle) != address(0)) {
            console.logString("Primary oracle is set, testing getLatestPrice...");
            
            try primaryOracle.getLatestPrice() returns (int256 p, uint256 t) {
                console.logString("SUCCESS: getLatestPrice returned:");
                console.logInt(p);
                console.logUint(t);
                console.logBool(p > 0);
                
                if (p > 0) {
                    console.logString("Price > 0, calculating USD...");
                    uint256 amountIn = 11539393896409733875338;
                    uint256 finalSwapAmountUSD = (amountIn * uint256(p)) / 1e30;
                    console.logString("Final USD amount:");
                    console.logUint(finalSwapAmountUSD);
                    
                    // Check threshold
                    uint256 minSwapAmount = 10000000; // $10 in 6 decimals
                    console.logString("Meets threshold:");
                    console.logBool(finalSwapAmountUSD >= minSwapAmount);
                } else {
                    console.logString("ERROR: Price <= 0");
                }
            } catch Error(string memory reason) {
                console.logString("ERROR: getLatestPrice failed:");
                console.logString(reason);
            } catch (bytes memory lowLevelData) {
                console.logString("ERROR: getLatestPrice low-level failure:");
                console.logBytes(lowLevelData);
            }
        } else {
            console.logString("ERROR: Primary oracle is address(0)");
        }
    }
}
