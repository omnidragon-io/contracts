// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/OmniDragonVRFConsumerV2_5.sol";

contract CheckVRFConsumerDeployment is Script {
    // Registry address (same across all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // Create2Factory with Ownership
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    
    // Same salt used in deployment
    bytes32 constant DEPLOYMENT_SALT = 0x564246496e7465677261746f7256332500000000000000000000000000000000;
    
    function run() external view {
        console.log("=== CHECKING VRF CONSUMER DEPLOYMENT ON ARBITRUM ===");
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        // Calculate expected address
        bytes memory bytecode = abi.encodePacked(
            type(OmniDragonVRFConsumerV2_5).creationCode,
            abi.encode(REGISTRY_ADDRESS)
        );
        
        address expectedAddress = vm.computeCreate2Address(
            DEPLOYMENT_SALT,
            keccak256(bytecode),
            OMNI_CREATE2_FACTORY
        );
        
        console.log("Expected Address:", expectedAddress);
        
        // Check if contract exists at this address
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(expectedAddress)
        }
        
        console.log("Code Size:", codeSize);
        console.log("Contract Deployed?", codeSize > 0 ? "YES" : "NO");
        
        if (codeSize > 0) {
            console.log("");
            console.log("CONTRACT DETAILS:");
            
            try OmniDragonVRFConsumerV2_5(payable(expectedAddress)).owner() returns (address owner) {
                console.log("  Owner:", owner);
            } catch {
                console.log("  Owner: FAILED TO READ");
            }
            
            try OmniDragonVRFConsumerV2_5(payable(expectedAddress)).registry() returns (address registry) {
                console.log("  Registry:", address(registry));
            } catch {
                console.log("  Registry: FAILED TO READ");
            }
            
            try OmniDragonVRFConsumerV2_5(payable(expectedAddress)).endpoint() returns (address endpoint) {
                console.log("  LayerZero Endpoint:", endpoint);
            } catch {
                console.log("  LayerZero Endpoint: FAILED TO READ");
            }
            
            try OmniDragonVRFConsumerV2_5(payable(expectedAddress)).vrfCoordinator() returns (address coordinator) {
                console.log("  VRF Coordinator:", address(coordinator));
            } catch {
                console.log("  VRF Coordinator: FAILED TO READ");
            }
            
            try OmniDragonVRFConsumerV2_5(payable(expectedAddress)).subscriptionId() returns (uint256 subId) {
                console.log("  Subscription ID:", subId);
            } catch {
                console.log("  Subscription ID: FAILED TO READ");
            }
            
            try OmniDragonVRFConsumerV2_5(payable(expectedAddress)).keyHash() returns (bytes32 keyHash) {
                console.log("  Key Hash:", vm.toString(keyHash));
            } catch {
                console.log("  Key Hash: FAILED TO READ");
            }
            
            console.log("");
            console.log("VRF CONSUMER SUCCESSFULLY DEPLOYED!");
            console.log("Address: ", expectedAddress);
        } else {
            console.log("");
            console.log("VRF CONSUMER NOT DEPLOYED - Need to retry deployment");
        }
        
        console.log("");
        console.log("VRF INTEGRATOR ADDRESSES TO PAIR:");
        console.log("  Sonic:     0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  Ethereum:  0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  Base:      0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  BSC:       0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("  Avalanche: 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
    }
}