// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";

contract CalculateActualVRFBytecode is Script {
    function run() external view {
        // The new registry address we use for constructor arguments
        address registryAddress = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
        
        // Calculate bytecode hash for ChainlinkVRFIntegratorV2_5
        // This should match exactly what was used during deployment
        bytes memory integratorBytecode = abi.encodePacked(
            type(ChainlinkVRFIntegratorV2_5).creationCode,
            abi.encode(registryAddress)
        );
        bytes32 integratorHash = keccak256(integratorBytecode);
        
        console.log("=== ACTUAL VRF INTEGRATOR BYTECODE HASH ===");
        console.log("Registry Address:", registryAddress);
        console.log("");
        console.log("ChainlinkVRFIntegratorV2_5:");
        console.log("  Bytecode Hash:", vm.toString(integratorHash));
        console.log("");
        console.log("Previous hash was: 0xefa6b1f85cdaa23b00c4ab937569467629191da5ecd46a2f0e8366752dd0320d");
        console.log("Current hash is: ", vm.toString(integratorHash));
        console.log("Hashes match?", integratorHash == 0xefa6b1f85cdaa23b00c4ab937569467629191da5ecd46a2f0e8366752dd0320d ? "YES" : "NO");
        
        console.log("");
        console.log("USE THIS HASH FOR VANITY GENERATION:");
        console.log(vm.toString(integratorHash));
    }
}