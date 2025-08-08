// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";
import "../contracts/interfaces/config/IOmniDragonRegistry.sol";

contract FixSonicEndpoint is Script {
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // Correct Sonic LayerZero endpoint
    address constant SONIC_LZ_ENDPOINT = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
    
    // Sonic configuration
    uint16 constant SONIC_CHAIN_ID = 146;
    uint32 constant SONIC_EID = 30332;
    address constant SONIC_WRAPPED_NATIVE = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38; // WS
    address constant SONIC_ROUTER = 0xF5F7231073b3B41c04BA655e1a7438b1a7b29c27; // Placeholder
    address constant SONIC_FACTORY = 0x05c1be79d3aC21Cc4B727eeD58C9B2fF757F5663; // Placeholder
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== FIXING SONIC ENDPOINT IN REGISTRY ===");
        console.log("Deployer:", deployer);
        console.log("Registry:", REGISTRY_ADDRESS);
        console.log("Current Sonic Endpoint: 0x1a44076050125825900e736c501f859c50fE728c");
        console.log("Correct Sonic Endpoint:", SONIC_LZ_ENDPOINT);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);

        OmniDragonRegistry registry = OmniDragonRegistry(REGISTRY_ADDRESS);
        
        // First, update the LayerZero endpoint for Sonic
        console.log("1. Updating Sonic LayerZero endpoint...");
        registry.setLayerZeroEndpoint(SONIC_CHAIN_ID, SONIC_LZ_ENDPOINT);
        console.log("   Sonic endpoint updated");
        
        // Register/configure Sonic chain
        console.log("2. Configuring Sonic chain...");
        try registry.getChainConfig(SONIC_CHAIN_ID) returns (IOmniDragonRegistry.ChainConfig memory) {
            // Chain already registered, update it
            console.log("   Sonic chain exists, updating configuration...");
            registry.updateChain(
                SONIC_CHAIN_ID,
                "Sonic",
                SONIC_WRAPPED_NATIVE,
                SONIC_ROUTER,
                SONIC_FACTORY
            );
        } catch {
            // Chain not registered, register it
            console.log("   Sonic chain not registered, registering...");
            registry.registerChain(
                SONIC_CHAIN_ID,
                "Sonic", 
                SONIC_WRAPPED_NATIVE,
                SONIC_ROUTER,
                SONIC_FACTORY,
                true // isActive
            );
        }
        console.log("   Sonic chain configured");
        
        // Set up Chain ID to EID mapping
        console.log("3. Setting up Chain ID to EID mapping...");
        registry.setChainIdToEid(SONIC_CHAIN_ID, SONIC_EID);
        console.log("   Chain ID to EID mapping set");

        vm.stopBroadcast();

        console.log("");
        console.log("CONFIGURATION COMPLETE!");
        console.log("==============================");
        
        // Verify the changes
        address newEndpoint = registry.getLayerZeroEndpoint(SONIC_CHAIN_ID);
        console.log("New Sonic Endpoint:", newEndpoint);
        console.log("Endpoint correct?", newEndpoint == SONIC_LZ_ENDPOINT ? "YES" : "NO");
        
        try registry.getChainConfig(SONIC_CHAIN_ID) returns (IOmniDragonRegistry.ChainConfig memory config) {
            console.log("Sonic chain name:", config.chainName);
            console.log("Sonic wrapped native:", config.wrappedNativeToken);
            console.log("Sonic is active:", config.isActive);
        } catch {
            console.log("ERROR: Sonic chain still not configured");
        }
        
        console.log("");
        console.log("NOW READY TO DEPLOY VRF INTEGRATOR!");
    }
}