// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/oracles/OmniDragonSecondaryOracle.sol";
import "../contracts/interfaces/config/IOmniDragonRegistry.sol";

contract GetSecondaryOracleBytecodeHash is Script {
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    address constant REGISTRY = 0x6949936442425f4137807Ac5d269e6Ef66d50777;

    function run() external view {
        // Required env: PRIMARY_ORACLE, PRIMARY_EID; endpoint resolved from registry for current chain
        address endpoint = IOmniDragonRegistry(REGISTRY).getLayerZeroEndpoint(uint16(block.chainid));
        address delegate = vm.envOr("DELEGATE", address(0));
        address primary = vm.envAddress("PRIMARY_ORACLE");
        uint32 primaryEid = uint32(vm.envUint("PRIMARY_EID"));

        if (delegate == address(0)) {
            // If not provided, default to deployer address preview (cannot access pk in view)
            delegate = address(0); // show as zero; deployment script should set real delegate
        }

        bytes memory initCode = abi.encodePacked(
            type(OmniDragonSecondaryOracle).creationCode,
            abi.encode(endpoint, delegate, primary, primaryEid)
        );

        bytes32 bytecodeHash = keccak256(initCode);

        console.log("=== SECONDARY ORACLE BYTECODE HASH ===");
        console.log("Factory:", OMNI_CREATE2_FACTORY);
        console.log("Endpoint:", endpoint);
        console.log("Delegate:", delegate);
        console.log("Primary:", primary);
        console.log("PrimaryEID:", primaryEid);
        console.log("BYTECODE HASH:");
        console.logBytes32(bytecodeHash);
        console.log("");
        console.log("Run vanity-generator:");
        console.log("cd vanity-generator");
        console.log("cargo run --release -- \\");
        console.log("  --factory", OMNI_CREATE2_FACTORY, "\\");
        console.log("  --bytecode-hash", vm.toString(bytecodeHash), "\\");
        console.log("  --starts-with 69 \\");
        console.log("  --ends-with 2777 \\");
        console.log("  --threads 8");
    }
}


