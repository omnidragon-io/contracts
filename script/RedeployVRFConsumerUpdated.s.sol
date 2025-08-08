// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/OmniDragonVRFConsumerV2_5.sol";

contract RedeployVRFConsumerUpdated is Script {
    // Updated registry address with vanity pattern
    address constant UPDATED_REGISTRY = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // Arbitrum VRF Configuration
    address constant VRF_COORDINATOR = 0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e;
    uint256 constant SUBSCRIPTION_ID = 49130512167777098004519592693541429977179420141459329604059253338290818062746;
    bytes32 constant KEY_HASH = 0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== REDEPLOYING OMNIDRAGON VRF CONSUMER V2.5 WITH UPDATED REGISTRY ===");
        console.log("Network: Arbitrum (Chain ID: 42161)");
        console.log("Deployer:", deployer);
        console.log("Updated Registry:", UPDATED_REGISTRY);
        console.log("Old Registry:", 0x69D485e1c69e2fB0B9Be0b800427c69D51d30777);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy with updated registry address
        OmniDragonVRFConsumerV2_5 vrfConsumer = new OmniDragonVRFConsumerV2_5(
            UPDATED_REGISTRY
        );
        
        // Configure VRF settings (using existing configuration)
        vrfConsumer.setVRFConfig(
            VRF_COORDINATOR,
            SUBSCRIPTION_ID,
            KEY_HASH
        );

        vm.stopBroadcast();

        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("New VRF Consumer Address:", address(vrfConsumer));
        console.log("Owner:", vrfConsumer.owner());
        console.log("Registry:", address(vrfConsumer.registry()));
        console.log("Endpoint:", address(vrfConsumer.endpoint()));
        console.log("VRF Coordinator:", address(vrfConsumer.vrfCoordinator()));
        console.log("Subscription ID:", vrfConsumer.subscriptionId());
        console.log("Key Hash:", vm.toString(vrfConsumer.keyHash()));
        
        // Verify deployment
        require(vrfConsumer.owner() == deployer, "Owner mismatch");
        require(address(vrfConsumer.registry()) == UPDATED_REGISTRY, "Registry mismatch");
        require(address(vrfConsumer.vrfCoordinator()) == VRF_COORDINATOR, "VRF Coordinator mismatch");
        require(vrfConsumer.subscriptionId() == SUBSCRIPTION_ID, "Subscription ID mismatch");
        
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Update LayerZero config with new address:", address(vrfConsumer));
        console.log("2. Set peer to Sonic VRF Integrator");
        console.log("3. Update layerzero.config.ts");
        console.log("4. Update deployment JSON files");
        console.log("5. Add VRF Consumer to Chainlink subscription");
        console.log("6. Configure LayerZero messaging pathways");
        
        console.log("");
        console.log("Old VRF Consumer:", 0x4CC1b5e72b9a5A6D6cE2131b444bB483FA2815c8);
        console.log("New VRF Consumer:", address(vrfConsumer));
    }
}