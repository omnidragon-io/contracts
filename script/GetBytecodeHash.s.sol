// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

contract GetBytecodeHash is Script {
    function run() external {
        // Use the same deployer address as in our main script
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== BYTECODE HASH EXTRACTION ===");
        console.log("Deployer:", deployer);
        
        // Get bytecode with constructor args (exactly like deployment script)
        bytes memory bytecode = abi.encodePacked(
            type(OmniDragonRegistry).creationCode,
            abi.encode(deployer)
        );
        
        // Calculate the hash
        bytes32 bytecodeHash = keccak256(bytecode);
        
        console.log("Bytecode length:", bytecode.length);
        console.log("Bytecode hash:", vm.toString(bytecodeHash));
        
        // Also show the CREATE2Factory address for reference
        console.log("CREATE2Factory:", 0xAA28020DDA6b954D16208eccF873D79AC6533833);
        
        console.log("");
        console.log("Use these values in the Rust vanity generator:");
        console.log("  --deployer 0xAA28020DDA6b954D16208eccF873D79AC6533833");
        console.log("  --bytecode-hash", vm.toString(bytecodeHash));
    }
}