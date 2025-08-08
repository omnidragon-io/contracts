// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/OmniDragonVRFConsumerV2_5.sol";

contract DeployVRFConsumerArbitrum is Script {
    // Registry address (same across all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // Create2Factory with Ownership
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    
    // Arbitrum VRF Configuration (from existing deployment)
    address constant VRF_COORDINATOR = 0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e;
    uint256 constant SUBSCRIPTION_ID = 49130512167777098004519592693541429977179420141459329604059253338290818062746;
    bytes32 constant KEY_HASH = 0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409;
    
    // Use a simple salt for predictable address
    bytes32 constant DEPLOYMENT_SALT = 0x564246496e7465677261746f7256332500000000000000000000000000000000; // "VRFConsumerV25" padded
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== VRF CONSUMER DEPLOYMENT ON ARBITRUM ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Registry Address:", REGISTRY_ADDRESS);
        console.log("Salt:", vm.toString(DEPLOYMENT_SALT));
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get bytecode with constructor args (registry address)
        bytes memory bytecode = abi.encodePacked(
            type(OmniDragonVRFConsumerV2_5).creationCode,
            abi.encode(REGISTRY_ADDRESS)
        );
        
        // Calculate CREATE2 address using the factory
        address predictedAddress = vm.computeCreate2Address(
            DEPLOYMENT_SALT,
            keccak256(bytecode),
            OMNI_CREATE2_FACTORY
        );
        
        console.log("Predicted Address:", predictedAddress);
        console.log("Using Create2Factory:", OMNI_CREATE2_FACTORY);
        
        // Deploy using CREATE2FactoryWithOwnership
        (bool success, bytes memory returnData) = OMNI_CREATE2_FACTORY.call(
            abi.encodeWithSignature("deploy(bytes,bytes32,string)", bytecode, DEPLOYMENT_SALT, "OmniDragonVRFConsumerV2_5")
        );
        
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("Factory deployment failed with no reason");
            }
        }
        
        // Get the deployed VRF consumer instance
        OmniDragonVRFConsumerV2_5 vrfConsumer = OmniDragonVRFConsumerV2_5(payable(predictedAddress));
        
        // Configure VRF settings immediately
        console.log("Configuring VRF settings...");
        vrfConsumer.setVRFConfig(
            VRF_COORDINATOR,
            SUBSCRIPTION_ID,
            KEY_HASH
        );
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("VRF Consumer Address:", address(vrfConsumer));
        console.log("Owner:", vrfConsumer.owner());
        console.log("Registry:", address(vrfConsumer.registry()));
        console.log("Endpoint:", address(vrfConsumer.endpoint()));
        console.log("VRF Coordinator:", address(vrfConsumer.vrfCoordinator()));
        console.log("Subscription ID:", vrfConsumer.subscriptionId());
        console.log("Key Hash:", vm.toString(vrfConsumer.keyHash()));
        
        // Verify deployment
        require(vrfConsumer.owner() == deployer, "Owner mismatch");
        require(address(vrfConsumer.registry()) == REGISTRY_ADDRESS, "Registry mismatch");
        require(address(vrfConsumer.vrfCoordinator()) == VRF_COORDINATOR, "VRF Coordinator mismatch");
        require(vrfConsumer.subscriptionId() == SUBSCRIPTION_ID, "Subscription ID mismatch");
        
        console.log("");
        console.log("VERIFICATION PASSED");
        console.log("VRF Consumer ready for LayerZero V2 configuration!");
        
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Set up LayerZero peers with VRF Integrators on other chains");
        console.log("2. Configure messaging pathways");
        console.log("3. Update layerzero.config.ts with new addresses");
        console.log("");
        console.log("VRF Integrator addresses to pair with:");
        console.log("  Sonic:    0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  Ethereum: 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  Base:     0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  BSC:      0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  Avalanche: 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
    }
}