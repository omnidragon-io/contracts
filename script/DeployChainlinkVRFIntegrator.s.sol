// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";

contract DeployChainlinkVRFIntegrator is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING CHAINLINK VRF INTEGRATOR V2.5 ===");
        console.log("Network: Sonic (Chain ID: 146)");
        console.log("Deployer:", deployer);
        
        // Sonic LayerZero V2 Endpoint
        address endpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
        
        vm.startBroadcast(deployerPrivateKey);

        ChainlinkVRFIntegratorV2_5 vrfIntegrator = new ChainlinkVRFIntegratorV2_5(
            0x69D485e1c69e2fB0B9Be0b800427c69D51d30777  // OmniDragonRegistry address (assuming same on Sonic)
        );

        vm.stopBroadcast();

        console.log("VRF Integrator deployed to:", address(vrfIntegrator));
        console.log("Owner:", vrfIntegrator.owner());
        console.log("Endpoint:", address(vrfIntegrator.endpoint()));
        
        // Verify deployment
        require(vrfIntegrator.owner() == deployer, "Owner mismatch");
        require(address(vrfIntegrator.endpoint()) == endpoint, "Endpoint mismatch");
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("Contract Address:", address(vrfIntegrator));
        console.log("Remember to:");
        console.log("1. Set peer to Arbitrum VRF Consumer");
        console.log("2. Update layerzero.setup.json");
        console.log("3. Configure LayerZero messaging");
    }
}