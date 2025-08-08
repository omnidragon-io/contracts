// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/tokens/omniDRAGON.sol";

contract GetDragonBytecodeHash is Script {
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    string constant TOKEN_NAME = "Dragon";
    string constant TOKEN_SYMBOL = "DRAGON";
    
    function run() external view {
        address deployer = 0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F; // Your deployer
        
        console.log("=== OMNIDRAGON BYTECODE HASH FOR VANITY GENERATION ===");
        console.log("Deployer:", deployer);
        console.log("Registry:", REGISTRY_ADDRESS);
        console.log("Token Name:", TOKEN_NAME);
        console.log("Token Symbol:", TOKEN_SYMBOL);
        console.log("");
        
        // Generate bytecode with constructor parameters
        bytes memory bytecode = abi.encodePacked(
            type(omniDRAGON).creationCode,
            abi.encode(
                TOKEN_NAME,        // "Dragon"
                TOKEN_SYMBOL,      // "DRAGON"
                deployer,          // delegate
                REGISTRY_ADDRESS,  // registry
                deployer           // owner
            )
        );
        
        bytes32 bytecodeHash = keccak256(bytecode);
        
        console.log("BYTECODE HASH:");
        console.log(vm.toString(bytecodeHash));
        
        console.log("");
        console.log("FACTORY ADDRESS:");
        console.log("0xAA28020DDA6b954D16208eccF873D79AC6533833");
        
        console.log("");
        console.log("RUST COMMAND TO FIND VANITY SALT:");
        console.log("cd vanity-generator");
        console.log("cargo run --release -- \\");
        console.log("  --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \\");
        console.log("  --bytecode-hash", vm.toString(bytecodeHash), "\\");
        console.log("  --starts-with 69 \\");
        console.log("  --ends-with 7777");
        
        console.log("");
        console.log("ALTERNATIVE WITH CUSTOM THREADS:");
        console.log("cargo run --release -- \\");
        console.log("  --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \\");
        console.log("  --bytecode-hash", vm.toString(bytecodeHash), "\\");
        console.log("  --starts-with 69 \\");
        console.log("  --ends-with 7777 \\");
        console.log("  --threads 8");
        
        console.log("");
        console.log("EXPECTED OUTPUT:");
        console.log("Salt: 0x[32-byte-hex]");
        console.log("Address: 0x69[anything]7777");
        
        console.log("");
        console.log("THEN UPDATE DeployVanityOmniDragon.s.sol:");
        console.log("- Set VANITY_SALT to the found salt");
        console.log("- Set EXPECTED_ADDRESS to the found address");
        console.log("- Deploy across all chains");
    }
}
