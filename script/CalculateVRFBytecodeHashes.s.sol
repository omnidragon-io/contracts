// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";
import "../contracts/core/vrf/OmniDragonVRFConsumerV2_5.sol";

contract CalculateVRFBytecodeHashes is Script {
    function run() external view {
        // The new registry address we'll use for constructor arguments
        address registryAddress = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
        
        // Calculate bytecode hash for ChainlinkVRFIntegratorV2_5
        bytes memory integratorBytecode = abi.encodePacked(
            type(ChainlinkVRFIntegratorV2_5).creationCode,
            abi.encode(registryAddress)
        );
        bytes32 integratorHash = keccak256(integratorBytecode);
        
        // Calculate bytecode hash for OmniDragonVRFConsumerV2_5
        bytes memory consumerBytecode = abi.encodePacked(
            type(OmniDragonVRFConsumerV2_5).creationCode,
            abi.encode(registryAddress)
        );
        bytes32 consumerHash = keccak256(consumerBytecode);
        
        console.log("=== VRF Contracts Bytecode Hashes ===");
        console.log("Registry Address:", registryAddress);
        console.log("");
        console.log("ChainlinkVRFIntegratorV2_5:");
        console.log("  Bytecode Hash:", vm.toString(integratorHash));
        console.log("");
        console.log("OmniDragonVRFConsumerV2_5:");
        console.log("  Bytecode Hash:", vm.toString(consumerHash));
    }
}