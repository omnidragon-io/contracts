// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../contracts/core/vrf/OmniDragonVRFConsumerV2_5.sol";

contract DeployOmniDragonVRFConsumer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING OMNIDRAGON VRF CONSUMER V2.5 ===");
        console.log("Network: Arbitrum (Chain ID: 42161)");
        console.log("Deployer:", deployer);
        
        // Arbitrum LayerZero V2 Endpoint
        address endpoint = 0x1a44076050125825900e736c501f859c50fE728c;
        
        // Chainlink VRF V2.5 Coordinator on Arbitrum
        address vrfCoordinator = 0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e;
        
        // VRF Configuration
        uint256 subscriptionId = 49130512167777098004519592693541429977179420141459329604059253338290818062746; // Your subscription ID
        bytes32 keyHash = 0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409; // 30 gwei key hash
        
        vm.startBroadcast(deployerPrivateKey);

        OmniDragonVRFConsumerV2_5 vrfConsumer = new OmniDragonVRFConsumerV2_5(
            0x69D485e1c69e2fB0B9Be0b800427c69D51d30777   // OmniDragonRegistry address on Arbitrum
        );
        
        // Configure VRF parameters after deployment
        vrfConsumer.setVRFConfig(
            vrfCoordinator,  // Chainlink VRF Coordinator
            subscriptionId,  // VRF subscription ID
            keyHash          // VRF key hash
        );

        vm.stopBroadcast();

        console.log("VRF Consumer deployed to:", address(vrfConsumer));
        console.log("Owner:", vrfConsumer.owner());
        console.log("Endpoint:", address(vrfConsumer.endpoint()));
        console.log("VRF Coordinator:", address(vrfConsumer.vrfCoordinator()));
        console.log("Subscription ID:", vrfConsumer.subscriptionId());
        
        // Verify deployment
        require(vrfConsumer.owner() == deployer, "Owner mismatch");
        require(address(vrfConsumer.endpoint()) == endpoint, "Endpoint mismatch");
        require(address(vrfConsumer.vrfCoordinator()) == vrfCoordinator, "VRF Coordinator mismatch");
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("Contract Address:", address(vrfConsumer));
        console.log("Remember to:");
        console.log("1. Set peer to Sonic VRF Integrator");
        console.log("2. Update layerzero.setup.json");
        console.log("3. Add contract as VRF consumer in Chainlink subscription");
        console.log("4. Configure LayerZero messaging");
    }
}