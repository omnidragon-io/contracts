// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";

contract VerifyCreate2Address is Script {
    function run() external view {
        // Parameters from the vanity generator
        address deployer = 0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F;
        bytes32 vanityGeneratorSalt = 0x2842410312732723c81fb6b53a245123933b7d4351f97d5495b1c5c9a4a96c02;
        bytes32 vanityGeneratorBytecode = 0xefa6b1f85cdaa23b00c4ab937569467629191da5ecd46a2f0e8366752dd0320d;
        
        // Parameters from deployment script
        address registryAddress = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
        address create2Factory = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
        
        console.log("=== CREATE2 ADDRESS VERIFICATION ===");
        console.log("Deployer:", deployer);
        console.log("Registry Address:", registryAddress);
        console.log("CREATE2 Factory:", create2Factory);
        console.log("");
        
        // Calculate actual bytecode hash
        bytes memory actualBytecode = abi.encodePacked(
            type(ChainlinkVRFIntegratorV2_5).creationCode,
            abi.encode(registryAddress)
        );
        bytes32 actualBytecodeHash = keccak256(actualBytecode);
        
        console.log("Vanity generator bytecode hash:", vm.toString(vanityGeneratorBytecode));
        console.log("Actual bytecode hash:         ", vm.toString(actualBytecodeHash));
        console.log("Bytecode hashes match?", actualBytecodeHash == vanityGeneratorBytecode ? "YES" : "NO");
        console.log("");
        
        // Calculate CREATE2 address using vanity generator parameters
        address vanityGeneratorAddress = vm.computeCreate2Address(
            vanityGeneratorSalt,
            vanityGeneratorBytecode,
            deployer // Note: using deployer, not factory
        );
        
        // Calculate CREATE2 address using actual deployment parameters
        address deploymentAddress = vm.computeCreate2Address(
            vanityGeneratorSalt,
            actualBytecodeHash,
            create2Factory // Note: using factory, not deployer
        );
        
        console.log("VANITY GENERATOR CALCULATION:");
        console.log("  Salt:", vm.toString(vanityGeneratorSalt));
        console.log("  Deployer:", deployer);
        console.log("  Expected Address:", vanityGeneratorAddress);
        console.log("");
        
        console.log("DEPLOYMENT CALCULATION:");
        console.log("  Salt:", vm.toString(vanityGeneratorSalt));
        console.log("  CREATE2 Factory:", create2Factory);
        console.log("  Calculated Address:", deploymentAddress);
        console.log("");
        
        console.log("Expected from vanity gen: 0x69d68432A3b84c1E0EDda982d2e13aef28ac3777");
        console.log("Actual deployment got:    0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5");
        console.log("");
        
        console.log("PROBLEM: We used DEPLOYER address in vanity generation");
        console.log("         But we used CREATE2_FACTORY address in deployment");
        console.log("         These are different addresses!");
    }
}