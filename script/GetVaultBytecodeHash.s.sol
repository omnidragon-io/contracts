// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/DragonJackpotVault.sol";

contract GetVaultBytecodeHash is Script {
    address constant OWNER = 0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F;

    function run() external view {
        // Match DeployVanityCore.s.sol: constructor(address(0), owner)
        bytes memory initCode = abi.encodePacked(
            type(DragonJackpotVault).creationCode,
            abi.encode(address(0), OWNER)
        );
        bytes32 bytecodeHash = keccak256(initCode);

        console.log("DRAGON_JACKPOT_VAULT BYTECODE HASH:");
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


