// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/core/oracles/OmniDragonOracle.sol";

contract GetInitBytecodeHash is Script {
    
    address constant REGISTRY_ADDRESS = 0x6940aDc0A505108bC11CA28EefB7E3BAc7AF0777;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== GETTING INIT BYTECODE HASH ===");
        console.log("Registry:", REGISTRY_ADDRESS);
        console.log("Deployer:", deployer);
        console.log("");
        
        // Get the creation bytecode with constructor arguments
        bytes memory creationCode = type(OmniDragonOracle).creationCode;
        bytes memory constructorArgs = abi.encode(REGISTRY_ADDRESS, deployer);
        bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);
        
        // Get the keccak256 hash
        bytes32 initCodeHash = keccak256(initCode);
        
        console.log("Creation code length:", creationCode.length);
        console.log("Constructor args length:", constructorArgs.length);
        console.log("Init code length:", initCode.length);
        console.log("");
        console.log("Init bytecode hash:");
        console.logBytes32(initCodeHash);
        console.log("");
        console.log("For vanity address tools:");
        console.log("Init hash (hex):", vm.toString(initCodeHash));
        
        // Also log the constructor args separately for reference
        console.log("");
        console.log("Constructor args (for reference):");
        console.logBytes(constructorArgs);
        
        // Show what a CREATE2 deployment would look like
        console.log("");
        console.log("=== CREATE2 INFO ===");
        console.log("To find vanity address, use these parameters:");
        console.log("- Deployer address:", deployer);
        console.log("- Init code hash:", vm.toString(initCodeHash));
        console.log("- Use vanity tools like 'create2crunch' or 'evm-create2-address'");
        console.log("");
        console.log("Example command (replace spaces with actual values):");
        console.log("create2crunch --init-code-hash [HASH] --caller [DEPLOYER] --prefix 69A366");
    }
}
