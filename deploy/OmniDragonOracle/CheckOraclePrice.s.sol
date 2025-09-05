// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../contracts/core/oracles/OmniDragonOracle.sol";

contract CheckOraclePrice is Script {
    function run() external view {
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        
        console.log("=== CHECKING ORACLE PRICES ===");
        console.log("Oracle Address:", oracleAddress);
        
        OmniDragonOracle oracle = OmniDragonOracle(payable(oracleAddress));
        
        // Check oracle status
        console.log("\n--- Oracle Status ---");
        try oracle.mode() returns (OmniDragonOracle.OracleMode mode) {
            console.log("Mode:", uint8(mode) == 0 ? "SECONDARY" : "PRIMARY");
        } catch {
            console.log("Mode: ERROR reading mode");
        }
        
        try oracle.priceInitialized() returns (bool initialized) {
            console.log("Price Initialized:", initialized);
        } catch {
            console.log("Price Initialized: ERROR reading status");
        }
        
        try oracle.twapEnabled() returns (bool enabled) {
            console.log("TWAP Enabled:", enabled);
        } catch {
            console.log("TWAP Enabled: ERROR reading status");
        }
        
        // Check latest price
        console.log("\n--- Latest Price ---");
        try oracle.getLatestPrice() returns (int256 price, uint256 timestamp) {
            console.log("Latest Price:", price);
            console.log("Price Timestamp:", timestamp);
            console.log("Current Block Timestamp:", block.timestamp);
            
            if (timestamp > 0) {
                uint256 age = block.timestamp - timestamp;
                console.log("Price Age (seconds):", age);
                console.log("Price Age (minutes):", age / 60);
            }
        } catch Error(string memory reason) {
            console.log("Latest Price: ERROR -", reason);
        } catch {
            console.log("Latest Price: ERROR reading price");
        }
        
        // Native token price function was removed from interface
        
        // Check TWAP data if enabled
        console.log("\n--- TWAP Data ---");
        try oracle.twapRatio18() returns (int256 ratio) {
            console.log("TWAP Ratio (18 decimals):", ratio);
            if (ratio != 0) {
                // Convert to readable format
                console.log("TWAP Ratio (readable):", uint256(ratio) / 1e18);
            }
        } catch {
            console.log("TWAP Ratio: ERROR reading ratio");
        }
        
        try oracle.lastUpdateTime() returns (uint256 updateTime) {
            console.log("Last TWAP Update:", updateTime);
            if (updateTime > 0) {
                uint256 age = block.timestamp - updateTime;
                console.log("TWAP Age (seconds):", age);
                console.log("TWAP Age (minutes):", age / 60);
            }
        } catch {
            console.log("Last TWAP Update: ERROR reading time");
        }
        
        // Check pair configuration
        console.log("\n--- DEX Pair Configuration ---");
        try oracle.dragonNativePair() returns (address pair) {
            console.log("DRAGON/Native Pair:", pair);
        } catch {
            console.log("DRAGON/Native Pair: ERROR reading pair");
        }
        
        try oracle.dragonToken() returns (address dragon) {
            console.log("DRAGON Token:", dragon);
        } catch {
            console.log("DRAGON Token: ERROR reading token");
        }
        
        try oracle.nativeToken() returns (address native) {
            console.log("Native Token:", native);
        } catch {
            console.log("Native Token: ERROR reading token");
        }
        
        console.log("\n=== PRICE CHECK COMPLETE ===");
    }
}
