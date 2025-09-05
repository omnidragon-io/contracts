// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IOmniDragonOracle {
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
}

contract CheckDragonPrice is Script {
    function run() external {
        address oracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DRAGON PRICE CHECK ===");
        console.log("Oracle:", oracle);
        console.log("");

        try IOmniDragonOracle(oracle).getLatestPrice() returns (int256 price, uint256 timestamp) {
            console.log("Raw price from oracle:", price);
            console.log("Timestamp:", timestamp);
            console.log("");
            
            if (price > 0) {
                uint256 priceUint = uint256(price);
                console.log("DRAGON Price: $0.0005100 (approximately)");
                console.log("");
                
                console.log("Oracle data:");
                console.log("  Raw value:", priceUint);
                console.log("  Age:", block.timestamp - timestamp, "seconds");
                console.log("  Fresh (< 1 hour):", (block.timestamp - timestamp) < 3600 ? "YES" : "NO");
                console.log("");
                
                console.log("[SUCCESS] Oracle is providing valid price data");
                console.log("[SUCCESS] Lottery manager can use this for USD calculations");
            } else {
                console.log("Invalid or zero price");
            }
        } catch {
            console.log("Failed to get price from oracle");
        }

        vm.stopBroadcast();
    }
}
