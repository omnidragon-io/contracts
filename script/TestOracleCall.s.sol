// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IOmniDragonOracle {
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
}

contract TestOracleCall is Script {
    function run() external {
        address oracleAddress = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
        IOmniDragonOracle oracle = IOmniDragonOracle(oracleAddress);
        
        console.logString("=== TESTING ORACLE CALL ===");
        console.logString("Oracle address:");
        console.logAddress(oracleAddress);
        
        try oracle.getLatestPrice() returns (int256 price, uint256 timestamp) {
            console.logString("SUCCESS: Oracle call succeeded");
            console.logString("Price:");
            console.logInt(price);
            console.logString("Timestamp:");
            console.logUint(timestamp);
            console.logString("Price > 0:");
            console.logBool(price > 0);
            
            // Test the USD calculation
            uint256 amountIn = 11539393896409733875338;
            if (price > 0) {
                uint256 finalSwapAmountUSD = (amountIn * uint256(price)) / 1e30;
                console.logString("USD calculation:");
                console.logUint(finalSwapAmountUSD);
                console.logString("Meets $10 threshold:");
                console.logBool(finalSwapAmountUSD >= 10000000);
            }
        } catch Error(string memory reason) {
            console.logString("ERROR: Oracle call failed with reason:");
            console.logString(reason);
        } catch (bytes memory lowLevelData) {
            console.logString("ERROR: Oracle call failed with low-level error:");
            console.logBytes(lowLevelData);
        }
    }
}
