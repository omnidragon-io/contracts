// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

contract ConfigureOmniDragonRegistry is Script {
    // Registry address (same on all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // LayerZero Endpoint IDs
    uint32 constant SONIC_EID = 30332;
    uint32 constant ARBITRUM_EID = 30110;
    uint32 constant ETHEREUM_EID = 30101;
    uint32 constant BASE_EID = 30184;
    uint32 constant AVALANCHE_EID = 30106;
    uint32 constant BSC_EID = 30102;
    
    // LayerZero Endpoints
    address constant SONIC_LZ_ENDPOINT = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
    address constant ARBITRUM_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant ETHEREUM_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant BASE_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant AVALANCHE_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant BSC_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    
    // Wrapped Native Tokens
    address constant SONIC_WRAPPED_NATIVE = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38; // WS
    address constant ARBITRUM_WRAPPED_NATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH
    address constant ETHEREUM_WRAPPED_NATIVE = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address constant BASE_WRAPPED_NATIVE = 0x4200000000000000000000000000000000000006; // WETH
    address constant AVALANCHE_WRAPPED_NATIVE = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7; // WAVAX
    address constant BSC_WRAPPED_NATIVE = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB
    
    // Official Uniswap V2 Router Addresses (from official deployments)
    address constant SONIC_ROUTER = 0xF5F7231073b3B41c04BA655e1a7438b1a7b29c27; // Placeholder - Uniswap V2 not on Sonic yet
    address constant ARBITRUM_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    address constant ETHEREUM_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Official Uniswap V2 Router
    address constant BASE_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    address constant AVALANCHE_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    address constant BSC_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    
    // Official Uniswap V2 Factory Addresses (from official deployments)
    address constant SONIC_FACTORY = 0x05c1be79d3aC21Cc4B727eeD58C9B2fF757F5663; // Placeholder - Uniswap V2 not on Sonic yet
    address constant ARBITRUM_FACTORY = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9; // Official Uniswap V2 Factory
    address constant ETHEREUM_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Official Uniswap V2 Factory
    address constant BASE_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6; // Official Uniswap V2 Factory
    address constant AVALANCHE_FACTORY = 0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C; // Official Uniswap V2 Factory
    address constant BSC_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6; // Official Uniswap V2 Factory

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== OMNIDRAGON REGISTRY CONFIGURATION ===");
        console.log("Registry Address:", REGISTRY_ADDRESS);
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        OmniDragonRegistry registry = OmniDragonRegistry(REGISTRY_ADDRESS);
        
        // Verify we're the owner
        require(registry.owner() == deployer, "Not the registry owner");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Configure LayerZero endpoints for current chain
        configureLayerZeroEndpoints(registry);
        
        // Register all supported chains
        registerAllChains(registry);
        
        // Set up chain ID to EID mappings
        configureChainMappings(registry);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("CONFIGURATION COMPLETED SUCCESSFULLY!");
        console.log("Registry configured for chain:", block.chainid);
    }
    
    function configureLayerZeroEndpoints(OmniDragonRegistry registry) internal {
        console.log("Configuring LayerZero endpoints...");
        
        if (block.chainid == 146) { // Sonic
            registry.setLayerZeroEndpoint(146, SONIC_LZ_ENDPOINT);
        } else if (block.chainid == 42161) { // Arbitrum
            registry.setLayerZeroEndpoint(42161, ARBITRUM_LZ_ENDPOINT);
        } else if (block.chainid == 1) { // Ethereum
            registry.setLayerZeroEndpoint(1, ETHEREUM_LZ_ENDPOINT);
        } else if (block.chainid == 8453) { // Base
            registry.setLayerZeroEndpoint(8453, BASE_LZ_ENDPOINT);
        } else if (block.chainid == 43114) { // Avalanche
            registry.setLayerZeroEndpoint(43114, AVALANCHE_LZ_ENDPOINT);
        } else if (block.chainid == 56) { // BSC
            registry.setLayerZeroEndpoint(56, BSC_LZ_ENDPOINT);
        }
        
        console.log("LayerZero endpoint configured for current chain");
    }
    
    function registerAllChains(OmniDragonRegistry registry) internal {
        console.log("Registering all supported chains...");
        
        // Register Sonic
        if (!registry.isSupportedChain(146)) {
            registry.registerChain(
                146,
                "Sonic",
                SONIC_WRAPPED_NATIVE,
                SONIC_ROUTER,
                SONIC_FACTORY,
                true
            );
            console.log("Registered Sonic (146)");
        }
        
        // Register Arbitrum
        if (!registry.isSupportedChain(42161)) {
            registry.registerChain(
                42161,
                "Arbitrum One",
                ARBITRUM_WRAPPED_NATIVE,
                ARBITRUM_ROUTER,
                ARBITRUM_FACTORY,
                true
            );
            console.log("Registered Arbitrum (42161)");
        }
        
        // Register Ethereum
        if (!registry.isSupportedChain(1)) {
            registry.registerChain(
                1,
                "Ethereum Mainnet",
                ETHEREUM_WRAPPED_NATIVE,
                ETHEREUM_ROUTER,
                ETHEREUM_FACTORY,
                true
            );
            console.log("Registered Ethereum (1)");
        }
        
        // Register Base
        if (!registry.isSupportedChain(8453)) {
            registry.registerChain(
                8453,
                "Base",
                BASE_WRAPPED_NATIVE,
                BASE_ROUTER,
                BASE_FACTORY,
                true
            );
            console.log("Registered Base (8453)");
        }
        
        // Register Avalanche
        if (!registry.isSupportedChain(43114)) {
            registry.registerChain(
                43114,
                "Avalanche C-Chain",
                AVALANCHE_WRAPPED_NATIVE,
                AVALANCHE_ROUTER,
                AVALANCHE_FACTORY,
                true
            );
            console.log("Registered Avalanche (43114)");
        }
        
        // Register BSC
        if (!registry.isSupportedChain(56)) {
            registry.registerChain(
                56,
                "BNB Smart Chain",
                BSC_WRAPPED_NATIVE,
                BSC_ROUTER,
                BSC_FACTORY,
                true
            );
            console.log("Registered BSC (56)");
        }
        
        console.log("All chains registered successfully");
    }
    
    function configureChainMappings(OmniDragonRegistry registry) internal {
        console.log("Configuring Chain ID to EID mappings...");
        
        // Set chain ID to EID mappings
        registry.setChainIdToEid(146, SONIC_EID);
        registry.setChainIdToEid(42161, ARBITRUM_EID);
        registry.setChainIdToEid(1, ETHEREUM_EID);
        registry.setChainIdToEid(8453, BASE_EID);
        registry.setChainIdToEid(43114, AVALANCHE_EID);
        registry.setChainIdToEid(56, BSC_EID);
        
        console.log("Chain mappings configured:");
        console.log("  Sonic (146) -> EID", SONIC_EID);
        console.log("  Arbitrum (42161) -> EID", ARBITRUM_EID);
        console.log("  Ethereum (1) -> EID", ETHEREUM_EID);
        console.log("  Base (8453) -> EID", BASE_EID);
        console.log("  Avalanche (43114) -> EID", AVALANCHE_EID);
        console.log("  BSC (56) -> EID", BSC_EID);
    }
}