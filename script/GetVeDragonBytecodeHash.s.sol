// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/tokens/veDRAGON.sol";

contract GetVeDragonBytecodeHash is Script {
    function run() external view {
        bytes memory initCode = abi.encodePacked(
            type(veDRAGON).creationCode,
            abi.encode("Voting Escrow DRAGON", "veDRAGON")
        );
        bytes32 bytecodeHash = keccak256(initCode);
        console.log("VEDRAGON BYTECODE HASH:");
        console.logBytes32(bytecodeHash);
        console.log("");
        console.log("Run vanity-generator:");
        console.log("cd vanity-generator");
        console.log("cargo run --release -- \\");
        console.log("  --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \\");
        console.log("  --bytecode-hash ", vm.toString(bytecodeHash), " \\");
        console.log("  --starts-with 69 \\");
        console.log("  --ends-with 777 \\");
        console.log("  --threads 8");
    }
}


