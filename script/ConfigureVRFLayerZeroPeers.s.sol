// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";
import "../contracts/core/vrf/OmniDragonVRFConsumerV2_5.sol";

contract ConfigureVRFLayerZeroPeers is Script {
    // VRF Contract addresses (same on all chains)
    address constant VRF_INTEGRATOR_ADDRESS = 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5;
    
    // Calculate VRF Consumer address (on Arbitrum)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    bytes32 constant DEPLOYMENT_SALT = 0x564246496e7465677261746f7256332500000000000000000000000000000000;
    
    // LayerZero EIDs
    uint32 constant SONIC_EID = 30332;
    uint32 constant ARBITRUM_EID = 30110;
    uint32 constant ETHEREUM_EID = 30101;
    uint32 constant BASE_EID = 30184;
    uint32 constant BSC_EID = 30102;
    uint32 constant AVALANCHE_EID = 30106;
    
    // Chain IDs
    uint256 constant SONIC_CHAIN_ID = 146;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;
    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant BASE_CHAIN_ID = 8453;
    uint256 constant BSC_CHAIN_ID = 56;
    uint256 constant AVALANCHE_CHAIN_ID = 43114;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== CONFIGURING VRF LAYERZERO PEERS ===");
        console.log("Current Chain ID:", block.chainid);
        
        // Calculate VRF Consumer address
        bytes memory consumerBytecode = abi.encodePacked(
            type(OmniDragonVRFConsumerV2_5).creationCode,
            abi.encode(REGISTRY_ADDRESS)
        );
        address vrfConsumerAddress = vm.computeCreate2Address(
            DEPLOYMENT_SALT,
            keccak256(consumerBytecode),
            OMNI_CREATE2_FACTORY
        );
        
        console.log("VRF Integrator Address:", VRF_INTEGRATOR_ADDRESS);
        console.log("VRF Consumer Address (Arbitrum):", vrfConsumerAddress);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        if (block.chainid == ARBITRUM_CHAIN_ID) {
            // Configure Arbitrum VRF Consumer to accept peers from all chains
            console.log("=== CONFIGURING ARBITRUM VRF CONSUMER ===");
            configureArbitrumConsumer(vrfConsumerAddress);
        } else if (block.chainid == SONIC_CHAIN_ID) {
            // Configure Sonic VRF Integrator
            console.log("=== CONFIGURING SONIC VRF INTEGRATOR ===");
            configureSonicIntegrator(vrfConsumerAddress);
        } else if (block.chainid == ETHEREUM_CHAIN_ID) {
            // Configure Ethereum VRF Integrator
            console.log("=== CONFIGURING ETHEREUM VRF INTEGRATOR ===");
            configureEthereumIntegrator(vrfConsumerAddress);
        } else if (block.chainid == BASE_CHAIN_ID) {
            // Configure Base VRF Integrator
            console.log("=== CONFIGURING BASE VRF INTEGRATOR ===");
            configureBaseIntegrator(vrfConsumerAddress);
        } else if (block.chainid == BSC_CHAIN_ID) {
            // Configure BSC VRF Integrator
            console.log("=== CONFIGURING BSC VRF INTEGRATOR ===");
            configureBSCIntegrator(vrfConsumerAddress);
        } else if (block.chainid == AVALANCHE_CHAIN_ID) {
            // Configure Avalanche VRF Integrator
            console.log("=== CONFIGURING AVALANCHE VRF INTEGRATOR ===");
            configureAvalancheIntegrator(vrfConsumerAddress);
        } else {
            console.log("Unknown chain - skipping configuration");
        }
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("CONFIGURATION COMPLETE!");
        console.log("Run this script on each chain to complete the setup:");
        console.log("1. Arbitrum (configure consumer)");
        console.log("2. Sonic (configure integrator)");
        console.log("3. Ethereum (configure integrator)");
        console.log("4. Base (configure integrator)");
        console.log("5. BSC (configure integrator)");
        console.log("6. Avalanche (configure integrator)");
    }
    
    function configureArbitrumConsumer(address vrfConsumerAddress) internal {
        OmniDragonVRFConsumerV2_5 consumer = OmniDragonVRFConsumerV2_5(payable(vrfConsumerAddress));
        
        console.log("Setting peers for VRF Consumer...");
        
        // Set peer for Sonic
        bytes32 sonicPeer = bytes32(uint256(uint160(VRF_INTEGRATOR_ADDRESS)));
        consumer.setPeer(SONIC_EID, sonicPeer);
        console.log("  Sonic peer set:", vm.toString(sonicPeer));
        
        // Set peer for Ethereum
        bytes32 ethereumPeer = bytes32(uint256(uint160(VRF_INTEGRATOR_ADDRESS)));
        consumer.setPeer(ETHEREUM_EID, ethereumPeer);
        console.log("  Ethereum peer set:", vm.toString(ethereumPeer));
        
        // Set peer for Base
        bytes32 basePeer = bytes32(uint256(uint160(VRF_INTEGRATOR_ADDRESS)));
        consumer.setPeer(BASE_EID, basePeer);
        console.log("  Base peer set:", vm.toString(basePeer));
        
        // Set peer for BSC
        bytes32 bscPeer = bytes32(uint256(uint160(VRF_INTEGRATOR_ADDRESS)));
        consumer.setPeer(BSC_EID, bscPeer);
        console.log("  BSC peer set:", vm.toString(bscPeer));
        
        // Set peer for Avalanche
        bytes32 avalanchePeer = bytes32(uint256(uint160(VRF_INTEGRATOR_ADDRESS)));
        consumer.setPeer(AVALANCHE_EID, avalanchePeer);
        console.log("  Avalanche peer set:", vm.toString(avalanchePeer));
        
        console.log("Arbitrum VRF Consumer configuration complete!");
    }
    
    function configureSonicIntegrator(address vrfConsumerAddress) internal {
        ChainlinkVRFIntegratorV2_5 integrator = ChainlinkVRFIntegratorV2_5(payable(VRF_INTEGRATOR_ADDRESS));
        
        console.log("Setting Arbitrum peer for Sonic VRF Integrator...");
        bytes32 arbitrumPeer = bytes32(uint256(uint160(vrfConsumerAddress)));
        integrator.setPeer(ARBITRUM_EID, arbitrumPeer);
        console.log("  Arbitrum peer set:", vm.toString(arbitrumPeer));
        
        console.log("Sonic VRF Integrator configuration complete!");
    }
    
    function configureEthereumIntegrator(address vrfConsumerAddress) internal {
        ChainlinkVRFIntegratorV2_5 integrator = ChainlinkVRFIntegratorV2_5(payable(VRF_INTEGRATOR_ADDRESS));
        
        console.log("Setting Arbitrum peer for Ethereum VRF Integrator...");
        bytes32 arbitrumPeer = bytes32(uint256(uint160(vrfConsumerAddress)));
        integrator.setPeer(ARBITRUM_EID, arbitrumPeer);
        console.log("  Arbitrum peer set:", vm.toString(arbitrumPeer));
        
        console.log("Ethereum VRF Integrator configuration complete!");
    }
    
    function configureBaseIntegrator(address vrfConsumerAddress) internal {
        ChainlinkVRFIntegratorV2_5 integrator = ChainlinkVRFIntegratorV2_5(payable(VRF_INTEGRATOR_ADDRESS));
        
        console.log("Setting Arbitrum peer for Base VRF Integrator...");
        bytes32 arbitrumPeer = bytes32(uint256(uint160(vrfConsumerAddress)));
        integrator.setPeer(ARBITRUM_EID, arbitrumPeer);
        console.log("  Arbitrum peer set:", vm.toString(arbitrumPeer));
        
        console.log("Base VRF Integrator configuration complete!");
    }
    
    function configureBSCIntegrator(address vrfConsumerAddress) internal {
        ChainlinkVRFIntegratorV2_5 integrator = ChainlinkVRFIntegratorV2_5(payable(VRF_INTEGRATOR_ADDRESS));
        
        console.log("Setting Arbitrum peer for BSC VRF Integrator...");
        bytes32 arbitrumPeer = bytes32(uint256(uint160(vrfConsumerAddress)));
        integrator.setPeer(ARBITRUM_EID, arbitrumPeer);
        console.log("  Arbitrum peer set:", vm.toString(arbitrumPeer));
        
        console.log("BSC VRF Integrator configuration complete!");
    }
    
    function configureAvalancheIntegrator(address vrfConsumerAddress) internal {
        ChainlinkVRFIntegratorV2_5 integrator = ChainlinkVRFIntegratorV2_5(payable(VRF_INTEGRATOR_ADDRESS));
        
        console.log("Setting Arbitrum peer for Avalanche VRF Integrator...");
        bytes32 arbitrumPeer = bytes32(uint256(uint160(vrfConsumerAddress)));
        integrator.setPeer(ARBITRUM_EID, arbitrumPeer);
        console.log("  Arbitrum peer set:", vm.toString(arbitrumPeer));
        
        console.log("Avalanche VRF Integrator configuration complete!");
    }
}