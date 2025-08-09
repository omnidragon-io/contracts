// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/oracles/OmniDragonPriceOracle.sol";

contract GetPriceOracleBytecodeHash is Script {
    address constant REGISTRY = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    address constant DRAGON = 0x69821FFA2312253209FdabB3D84f034B697E7777;
    address constant OWNER = 0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F;

    function run() external view {
        bytes memory initCode = abi.encodePacked(
            type(OmniDragonPriceOracle).creationCode,
            abi.encode("NATIVE", "USD", OWNER, REGISTRY, DRAGON)
        );
        bytes32 bytecodeHash = keccak256(initCode);
        console.log("PRICE_ORACLE BYTECODE HASH:");
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


