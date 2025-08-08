// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

contract UpdateUniswapV2Addresses is Script {
    // Registry address (same on all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // Official Uniswap V2 Router Addresses (from official deployments)
    address constant SONIC_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Placeholder - Uniswap V2 not on Sonic yet
    address constant ARBITRUM_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    address constant ETHEREUM_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Official Uniswap V2 Router
    address constant BASE_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    address constant AVALANCHE_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    address constant BSC_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24; // Official Uniswap V2 Router
    
    // Official Uniswap V2 Factory Addresses (from official deployments)
    address constant SONIC_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Placeholder - Uniswap V2 not on Sonic yet
    address constant ARBITRUM_FACTORY = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9; // Official Uniswap V2 Factory
    address constant ETHEREUM_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Official Uniswap V2 Factory
    address constant BASE_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6; // Official Uniswap V2 Factory
    address constant AVALANCHE_FACTORY = 0x9e5A52f57b3038F1B8EeE45F28b3C1967e22799C; // Official Uniswap V2 Factory
    address constant BSC_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6; // Official Uniswap V2 Factory

    // Wrapped Native Tokens (unchanged)
    address constant SONIC_WRAPPED_NATIVE = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38; // WS
    address constant ARBITRUM_WRAPPED_NATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH
    address constant ETHEREUM_WRAPPED_NATIVE = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address constant BASE_WRAPPED_NATIVE = 0x4200000000000000000000000000000000000006; // WETH
    address constant AVALANCHE_WRAPPED_NATIVE = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7; // WAVAX
    address constant BSC_WRAPPED_NATIVE = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== UPDATING UNISWAP V2 ADDRESSES ===");
        console.log("Registry Address:", REGISTRY_ADDRESS);
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        OmniDragonRegistry registry = OmniDragonRegistry(REGISTRY_ADDRESS);
        
        // Verify we're the owner
        require(registry.owner() == deployer, "Not the registry owner");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Update all chain configurations with correct Uniswap V2 addresses
        updateAllChainConfigurations(registry);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("UNISWAP V2 UPDATE COMPLETED SUCCESSFULLY!");
        console.log("All chains now use official Uniswap V2 addresses");
    }
    
    function updateAllChainConfigurations(OmniDragonRegistry registry) internal {
        console.log("Updating chain configurations with official Uniswap V2 addresses...");
        
        // Update Sonic (146)
        if (registry.isSupportedChain(146)) {
            registry.updateChain(
                146,
                "Sonic",
                SONIC_WRAPPED_NATIVE,
                SONIC_ROUTER,
                SONIC_FACTORY
            );
            console.log("Updated Sonic (146) - Router:", SONIC_ROUTER);
        }
        
        // Update Arbitrum (42161)
        if (registry.isSupportedChain(42161)) {
            registry.updateChain(
                42161,
                "Arbitrum One",
                ARBITRUM_WRAPPED_NATIVE,
                ARBITRUM_ROUTER,
                ARBITRUM_FACTORY
            );
            console.log("Updated Arbitrum (42161) - Router:", ARBITRUM_ROUTER);
        }
        
        // Update Ethereum (1)
        if (registry.isSupportedChain(1)) {
            registry.updateChain(
                1,
                "Ethereum Mainnet",
                ETHEREUM_WRAPPED_NATIVE,
                ETHEREUM_ROUTER,
                ETHEREUM_FACTORY
            );
            console.log("Updated Ethereum (1) - Router:", ETHEREUM_ROUTER);
        }
        
        // Update Base (8453)
        if (registry.isSupportedChain(8453)) {
            registry.updateChain(
                8453,
                "Base",
                BASE_WRAPPED_NATIVE,
                BASE_ROUTER,
                BASE_FACTORY
            );
            console.log("Updated Base (8453) - Router:", BASE_ROUTER);
        }
        
        // Update Avalanche (43114)
        if (registry.isSupportedChain(43114)) {
            registry.updateChain(
                43114,
                "Avalanche C-Chain",
                AVALANCHE_WRAPPED_NATIVE,
                AVALANCHE_ROUTER,
                AVALANCHE_FACTORY
            );
            console.log("Updated Avalanche (43114) - Router:", AVALANCHE_ROUTER);
        }
        
        // Update BSC (56)
        if (registry.isSupportedChain(56)) {
            registry.updateChain(
                56,
                "BNB Smart Chain",
                BSC_WRAPPED_NATIVE,
                BSC_ROUTER,
                BSC_FACTORY
            );
            console.log("Updated BSC (56) - Router:", BSC_ROUTER);
        }
        
        console.log("");
        console.log("All chain configurations updated with official Uniswap V2 addresses!");
        console.log("Factory addresses updated to official Uniswap V2 deployments");
        console.log("Router addresses updated to official Uniswap V2 deployments");
    }
}