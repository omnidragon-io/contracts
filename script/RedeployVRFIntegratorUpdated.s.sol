// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";

contract RedeployVRFIntegratorUpdated is Script {
    // Updated registry address with vanity pattern
    address constant UPDATED_REGISTRY = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== REDEPLOYING CHAINLINK VRF INTEGRATOR V2.5 WITH UPDATED REGISTRY ===");
        console.log("Network: Sonic (Chain ID: 146)");
        console.log("Deployer:", deployer);
        console.log("Updated Registry:", UPDATED_REGISTRY);
        console.log("Old Registry:", 0x69D485e1c69e2fB0B9Be0b800427c69D51d30777);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy with updated registry address
        ChainlinkVRFIntegratorV2_5 vrfIntegrator = new ChainlinkVRFIntegratorV2_5(
            UPDATED_REGISTRY
        );

        vm.stopBroadcast();

        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("New VRF Integrator Address:", address(vrfIntegrator));
        console.log("Owner:", vrfIntegrator.owner());
        console.log("Registry:", address(vrfIntegrator.registry()));
        console.log("Endpoint:", address(vrfIntegrator.endpoint()));
        
        // Verify deployment
        require(vrfIntegrator.owner() == deployer, "Owner mismatch");
        require(address(vrfIntegrator.registry()) == UPDATED_REGISTRY, "Registry mismatch");
        
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Update LayerZero config with new address:", address(vrfIntegrator));
        console.log("2. Set peer to Arbitrum VRF Consumer");
        console.log("3. Update layerzero.config.ts");
        console.log("4. Update deployment JSON files");
        console.log("5. Configure LayerZero messaging pathways");
        
        console.log("");
        console.log("Old VRF Integrator:", 0x4cc69C8FEd6d340742a347905ac99DdD5b2B0A90);
        console.log("New VRF Integrator:", address(vrfIntegrator));
    }
}