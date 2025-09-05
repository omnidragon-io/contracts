// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IOmniDragonOracle {
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
    function priceInitialized() external view returns (bool);
    function latestPrice() external view returns (int256);
    function lastUpdateTime() external view returns (uint256);
}

contract DebugOracleIssue is Script {
    function run() external {
        address oracleAddr = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
        IOmniDragonOracle oracle = IOmniDragonOracle(oracleAddr);

        console.logString("=== DEBUGGING ORACLE ISSUE ===");

        // Check all state variables
        bool initialized = oracle.priceInitialized();
        int256 latestPrice = oracle.latestPrice();
        uint256 lastUpdateTime = oracle.lastUpdateTime();

        console.logString("priceInitialized:");
        console.logBool(initialized);
        console.logString("latestPrice:");
        console.logInt(latestPrice);
        console.logString("lastUpdateTime:");
        console.logUint(lastUpdateTime);
        console.logString("current block.timestamp (approx):");
        console.logUint(block.timestamp);
        console.logString("staleness check (should be false):");
        console.logBool(block.timestamp > lastUpdateTime + 86400);

        // Now call getLatestPrice
        console.logString("\nCalling getLatestPrice()...");
        try oracle.getLatestPrice() returns (int256 p, uint256 t) {
            console.logString("getLatestPrice() returned:");
            console.logInt(p);
            console.logUint(t);
            console.logString("p > 0:");
            console.logBool(p > 0);
        } catch Error(string memory reason) {
            console.logString("ERROR:");
            console.logString(reason);
        } catch (bytes memory data) {
            console.logString("Low-level error:");
            console.logBytes(data);
        }
    }
}
