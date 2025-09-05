// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OmniDragonOracle} from "../contracts/core/oracles/OmniDragonOracle.sol";

contract InitiatePrice is Script {
    // Sonic oracle address
    address constant SONIC_ORACLE = 0x698cFFa2Aa94348796f6B923Ef285De6997B6777;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Initiating Price Update ===");
        console.log("Sonic Oracle:", SONIC_ORACLE);
        console.log("Deployer:", deployer);
        console.log("");
        
        OmniDragonOracle sonicOracle = OmniDragonOracle(payable(SONIC_ORACLE));
        
        // Check current state
        address owner = sonicOracle.owner();
        console.log("Current Owner:", owner);
        console.log("Deployer is Owner:", owner == deployer);
        
        uint8 currentMode = uint8(sonicOracle.mode());
        console.log("Current Mode:", currentMode == 1 ? "PRIMARY" : 
                                     currentMode == 2 ? "SECONDARY" : "OTHER");
        console.log("");
        
        // Test current price BEFORE update
        console.log("=== Price Before Update ===");
        (int256 priceBefore, uint256 timestampBefore) = sonicOracle.getLatestPrice();
        console.log("Price Before:");
        console.logInt(priceBefore);
        console.log("Timestamp Before:", timestampBefore);
        console.log("Price Initialized Before:", sonicOracle.priceInitialized());
        console.log("");
        
        // Check individual oracle sources
        console.log("=== Individual Oracle Sources ===");
        try sonicOracle.getChainlinkPrice() returns (int256 chainlinkPrice, bool chainlinkValid) {
            console.log("Chainlink Price:");
            console.logInt(chainlinkPrice);
            console.log("Chainlink Valid:", chainlinkValid);
        } catch {
            console.log("Chainlink: Failed to read");
        }
        
        try sonicOracle.getPythPrice() returns (int256 pythPrice, bool pythValid) {
            console.log("Pyth Price:");
            console.logInt(pythPrice);
            console.log("Pyth Valid:", pythValid);
        } catch {
            console.log("Pyth: Failed to read");
        }
        
        try sonicOracle.getBandPrice() returns (int256 bandPrice, bool bandValid) {
            console.log("Band Price:");
            console.logInt(bandPrice);
            console.log("Band Valid:", bandValid);
        } catch {
            console.log("Band: Failed to read");
        }
        
        try sonicOracle.getAPI3Price() returns (int256 api3Price, bool api3Valid) {
            console.log("API3 Price:");
            console.logInt(api3Price);
            console.log("API3 Valid:", api3Valid);
        } catch {
            console.log("API3: Failed to read");
        }
        console.log("");
        
        require(owner == deployer, "Deployer must be owner to update price");
        require(currentMode == 1, "Oracle must be in PRIMARY mode");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Force price update
        console.log("=== Forcing Price Update ===");
        try sonicOracle.updatePrice() {
            console.log("SUCCESS: Price update called successfully");
        } catch {
            console.log("WARNING: Price update failed - might need oracle sources configured");
        }
        
        vm.stopBroadcast();
        
        // Test price AFTER update
        console.log("=== Price After Update ===");
        (int256 priceAfter, uint256 timestampAfter) = sonicOracle.getLatestPrice();
        console.log("Price After:");
        console.logInt(priceAfter);
        console.log("Timestamp After:", timestampAfter);
        console.log("Price Initialized After:", sonicOracle.priceInitialized());
        console.log("");
        
        // Check if price changed
        bool priceChanged = (priceBefore != priceAfter) || (timestampBefore != timestampAfter);
        console.log("Price Changed:", priceChanged);
        console.log("Timestamp Updated:", timestampAfter > timestampBefore);
        console.log("");
        
        console.log("PRICE INITIATION COMPLETE!");
        console.log("Oracle is now ready for cross-chain requests!");
        
        if (priceAfter != 0) {
            console.log("SUCCESS: Oracle has valid price data");
        } else {
            console.log("WARNING: Oracle still returning zero price");
            console.log("Recommendation: Check if price feed addresses are correct");
            console.log("Recommendation: Ensure price feeds have recent data");
        }
    }
}
