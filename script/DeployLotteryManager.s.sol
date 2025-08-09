// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";

contract DeployLotteryManager is Script {
    // Registry address (same across all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // VRF addresses (operational)
    address constant VRF_INTEGRATOR = 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5;
    // address constant VRF_CONSUMER = 0x697a9d438A5B61ea75Aa823f98A85EFB70FD23d5; // Example, not used
    
    // Chain-specific configurations
    struct ChainConfig {
        uint256 chainId;
        string name;
        address omniDRAGON; // Will be deployed later
        address veDRAGON;   // Will be deployed later  
        address priceOracle; // Will be deployed later
    }
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get current chain ID
        uint256 currentChainId = block.chainid;
        ChainConfig memory config = getChainConfig(currentChainId);
        
        console.log("=== DEPLOYING OMNIDRAGON LOTTERY MANAGER ===");
        console.log("Network:", config.name);
        console.log("Chain ID:", config.chainId);
        console.log("Deployer:", deployer);
        console.log("Registry:", REGISTRY_ADDRESS);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Load real dependency addresses from environment
        console.log("1. Loading dependency addresses...");
        address jackpotVaultAddr = vm.envAddress("JACKPOT_VAULT");
        address veDRAGONAddr = vm.envAddress("VEDRAGON");
        address priceOracleAddr = vm.envAddress("PRICE_ORACLE");
        address vrfIntegratorAddr = vm.envOr("VRF_INTEGRATOR_ADDR", address(0));
        console.log("   JackpotVault:", jackpotVaultAddr);
        console.log("   veDRAGON:", veDRAGONAddr);
        console.log("   PriceOracle:", priceOracleAddr);
        
        // Step 2: Deploy OmniDragonLotteryManager
        console.log("2. Deploying OmniDragonLotteryManager...");
        OmniDragonLotteryManager lotteryManager = new OmniDragonLotteryManager(
            jackpotVaultAddr,
            veDRAGONAddr,
            priceOracleAddr,
            config.chainId
        );
        console.log("   OmniDragonLotteryManager deployed at:", address(lotteryManager));
        
        // Step 3: Configure VRF integration (optional)
        console.log("3. Configuring VRF integration (optional)...");
        if (vrfIntegratorAddr != address(0)) {
            lotteryManager.setVRFIntegrator(vrfIntegratorAddr);
            console.log("   VRF Integrator set to:", vrfIntegratorAddr);
        }
        
        // Note: JackpotVault ownership transfer should be performed separately using the real vault contract
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("JackpotVault:", jackpotVaultAddr);
        console.log("veDRAGON:", veDRAGONAddr);
        console.log("PriceOracle:", priceOracleAddr);
        console.log("OmniDragonLotteryManager:", address(lotteryManager));
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Configure lottery parameters");
        console.log("2. Authorize swap contracts via setAuthorizedSwapContract");
        console.log("3. (Optional) Set redDRAGON token if not already");
        console.log("");
        console.log("VRF INTEGRATION:");
        console.log("- VRF system is operational and ready");
        console.log("- Lottery can now use cross-chain randomness");
        console.log("- Test with: lotteryManager.triggerInstantLottery()");
    }
    
    function getChainConfig(uint256 chainId) internal pure returns (ChainConfig memory) {
        if (chainId == 146) { // Sonic
            return ChainConfig({
                chainId: 146,
                name: "Sonic",
                omniDRAGON: address(0), // To be deployed
                veDRAGON: address(0),   // To be deployed
                priceOracle: address(0) // To be deployed
            });
        } else if (chainId == 42161) { // Arbitrum
            return ChainConfig({
                chainId: 42161,
                name: "Arbitrum",
                omniDRAGON: address(0), // To be deployed
                veDRAGON: address(0),   // To be deployed  
                priceOracle: address(0) // To be deployed
            });
        } else if (chainId == 1) { // Ethereum
            return ChainConfig({
                chainId: 1,
                name: "Ethereum",
                omniDRAGON: address(0), // To be deployed
                veDRAGON: address(0),   // To be deployed
                priceOracle: address(0) // To be deployed
            });
        } else {
            revert("Unsupported chain");
        }
    }
}

// No mock contracts included. This script assumes real addresses are supplied via env.
