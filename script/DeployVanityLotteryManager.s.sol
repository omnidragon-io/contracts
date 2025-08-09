// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";

contract DeployVanityLotteryManager is Script {
    // Omni create2 factory
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Load dependencies from env
        address jackpotVault = vm.envAddress("JACKPOT_VAULT");
        address veDRAGON = vm.envAddress("VEDRAGON");
        address priceOracle = vm.envAddress("PRICE_ORACLE");

        // Vanity salt (provide via env)
        bytes32 salt = vm.envBytes32("SALT_LOTTERY");

        // Build initCode
        bytes memory initCode = abi.encodePacked(
            type(OmniDragonLotteryManager).creationCode,
            abi.encode(jackpotVault, veDRAGON, priceOracle, block.chainid)
        );

        // Compute expected address
        address expected = vm.computeCreate2Address(
            salt,
            keccak256(initCode),
            OMNI_CREATE2_FACTORY
        );

        console.log("Deploying OmniDragonLotteryManager with vanity...");
        console.log("  JackpotVault:", jackpotVault);
        console.log("  veDRAGON:", veDRAGON);
        console.log("  PriceOracle:", priceOracle);
        console.log("  Salt:", vm.toString(salt));
        console.log("  Expected Address:", expected);

        if (expected.code.length == 0) {
            (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, salt, "OmniDragonLotteryManager")
            );
            require(ok, "LotteryManager deploy failed");
        } else {
            console.log("OmniDragonLotteryManager exists:", expected);
        }
        console.log("OmniDragonLotteryManager:", expected);

        vm.stopBroadcast();
    }
}


