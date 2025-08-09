// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/DragonJackpotVault.sol";
import "../contracts/core/oracles/OmniDragonPriceOracle.sol";
import "../contracts/core/tokens/veDRAGON.sol";
import "../contracts/core/governance/voting/veDRAGONRevenueDistributor.sol";

contract DeployCoreDependencies is Script {
    // Registry address (same across all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;
        string memory chainName = getChainName(chainId);
        
        console.log("=== DEPLOYING CORE DEPENDENCIES ===");
        console.log("Network:", chainName);
        console.log("Chain ID:", chainId);
        console.log("Deployer:", deployer);
        console.log("Registry:", REGISTRY_ADDRESS);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy DragonJackpotVault (needs wrapped native token)
        console.log("1. Deploying DragonJackpotVault...");
        address wrappedNative = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38; // WS on Sonic
        DragonJackpotVault jackpotVault = new DragonJackpotVault(wrappedNative, deployer);
        console.log("   SUCCESS: DragonJackpotVault deployed at:", address(jackpotVault));
        
        // Step 2: Deploy OmniDragonPriceOracle (real)
        console.log("2. Deploying OmniDragonPriceOracle...");
        address omniDRAGON = 0x69821FFA2312253209FdabB3D84f034B697E7777;
        OmniDragonPriceOracle priceOracle = new OmniDragonPriceOracle(
            "S",           // nativeSymbol (Sonic)
            "USD",         // quoteSymbol
            deployer,      // initialOwner
            REGISTRY_ADDRESS, // registry
            omniDRAGON     // dragonToken
        );
        console.log("   SUCCESS: OmniDragonPriceOracle deployed at:", address(priceOracle));
        
        // Step 3: Deploy veDRAGON Token (real)
        console.log("3. Deploying veDRAGON Token...");
        veDRAGON veDragonToken = new veDRAGON("Voting Escrow DRAGON", "veDRAGON");
        veDragonToken.initialize(omniDRAGON, veDRAGON.TokenType.DRAGON);
        console.log("   SUCCESS: veDRAGON deployed at:", address(veDragonToken));
        
        // Step 4: Deploy veDRAGON Revenue Distributor
        console.log("4. Deploying veDRAGON Revenue Distributor...");
        veDRAGONRevenueDistributor revenueDistributor = new veDRAGONRevenueDistributor(
            address(veDragonToken) // veDRAGON address
        );
        console.log("   SUCCESS: veDRAGON Revenue Distributor deployed at:", address(revenueDistributor));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("Chain:", chainName);
        console.log("Chain ID:", chainId);
        console.log("DragonJackpotVault:", address(jackpotVault));
        console.log("OmniDragonPriceOracle:", address(priceOracle));
        console.log("veDRAGON:", address(veDragonToken));
        console.log("veDRAGONRevenueDistributor:", address(revenueDistributor));
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Configure omniDRAGON token with these contract addresses");
        console.log("2. Set up oracle price feeds");
        console.log("3. Deploy OmniDragonLotteryManager");
        console.log("4. Test cross-chain transfers");
        console.log("");
        console.log("READY FOR:");
        console.log("- Lottery Manager deployment");
        console.log("- Cross-chain token transfers");
        console.log("- Fee distribution system");
    }
    
    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 146) return "Sonic";
        if (chainId == 42161) return "Arbitrum"; 
        if (chainId == 1) return "Ethereum";
        if (chainId == 8453) return "Base";
        if (chainId == 43114) return "Avalanche";
        if (chainId == 56) return "BSC";
        return "Unknown";
    }
}
