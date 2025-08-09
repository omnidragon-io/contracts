// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";

contract GetLotteryManagerBytecodeHash is Script {
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;

    function run() external view {
        // Load constructor args from env
        address jackpotVault = vm.envAddress("JACKPOT_VAULT");
        address veDRAGONAddr = vm.envAddress("VEDRAGON");
        address priceOracleAddr = vm.envAddress("PRICE_ORACLE");
        uint256 chainId = block.chainid;

        console.log("=== LOTTERY MANAGER BYTECODE HASH FOR VANITY GENERATION ===");
        console.log("Factory:", OMNI_CREATE2_FACTORY);
        console.log("JackpotVault:", jackpotVault);
        console.log("veDRAGON:", veDRAGONAddr);
        console.log("PriceOracle:", priceOracleAddr);
        console.log("ChainId:", chainId);
        console.log("");

        bytes memory initCode = abi.encodePacked(
            type(OmniDragonLotteryManager).creationCode,
            abi.encode(jackpotVault, veDRAGONAddr, priceOracleAddr, chainId)
        );

        bytes32 bytecodeHash = keccak256(initCode);
        console.log("BYTECODE HASH:");
        console.logBytes32(bytecodeHash);

        console.log("");
        console.log("Run vanity-generator:");
        console.log("cd vanity-generator");
        console.log("cargo run --release -- \\");
        console.log("  --factory", OMNI_CREATE2_FACTORY, "\\");
        console.log("  --bytecode-hash", vm.toString(bytecodeHash), "\\");
        console.log("  --starts-with 69 \\");
        console.log("  --ends-with 777 \\");
        console.log("  --threads 8");
    }
}


