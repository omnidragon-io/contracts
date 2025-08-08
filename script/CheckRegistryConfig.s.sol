// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";
import "../contracts/interfaces/config/IOmniDragonRegistry.sol";

contract CheckRegistryConfig is Script {
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    function run() external view {
        OmniDragonRegistry registry = OmniDragonRegistry(REGISTRY_ADDRESS);
        
        console.log("=== REGISTRY CONFIGURATION CHECK ===");
        console.log("Registry Address:", REGISTRY_ADDRESS);
        console.log("");
        
        // Check Sonic configuration (Chain ID 146)
        console.log("Sonic (Chain ID 146):");
        try registry.getLayerZeroEndpoint(146) returns (address endpoint) {
            console.log("  LayerZero Endpoint:", endpoint);
        } catch {
            console.log("  LayerZero Endpoint: NOT CONFIGURED");
        }
        
        try registry.getChainConfig(146) returns (
            IOmniDragonRegistry.ChainConfig memory config
        ) {
            console.log("  Chain Name:", config.chainName);
            console.log("  Wrapped Native:", config.wrappedNativeToken);
            console.log("  Wrapped Native Symbol:", config.wrappedNativeSymbol);
            console.log("  Uniswap V2 Router:", config.uniswapV2Router);
            console.log("  Uniswap V2 Factory:", config.uniswapV2Factory);
            console.log("  Is Active:", config.isActive);
        } catch {
            console.log("  Chain Config: NOT CONFIGURED");
        }
        
        console.log("");
        
        // Check Arbitrum configuration (Chain ID 42161)
        console.log("Arbitrum (Chain ID 42161):");
        try registry.getLayerZeroEndpoint(42161) returns (address endpoint) {
            console.log("  LayerZero Endpoint:", endpoint);
        } catch {
            console.log("  LayerZero Endpoint: NOT CONFIGURED");
        }
        
        console.log("");
        console.log("Expected Sonic Endpoint: 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B");
        console.log("Expected Arbitrum Endpoint: 0x1a44076050125825900e736c501f859c50fE728c");
    }
}