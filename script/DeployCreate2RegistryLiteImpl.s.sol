// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistryLite.sol";

contract DeployCreate2RegistryLiteImpl is Script {
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("REGISTRY_OWNER", vm.addr(pk));
        bytes32 salt = vm.envBytes32("SALT_IMPL");
        require(salt != bytes32(0), "SALT_IMPL required");

        vm.startBroadcast(pk);

        // Init code for Lite implementation
        bytes memory initCode = abi.encodePacked(
            type(OmniDragonRegistryLite).creationCode,
            abi.encode(owner)
        );

        address expected = vm.computeCreate2Address(salt, keccak256(initCode), OMNI_CREATE2_FACTORY);
        console.log("Deploying Lite Impl via CREATE2...");
        console.log("  Owner:", owner);
        console.log("  Salt:", vm.toString(salt));
        console.log("  Expected:", expected);

        if (expected.code.length == 0) {
            (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, salt, "OmniDragonRegistryLite")
            );
            require(ok, "Lite impl deploy failed");
        } else {
            console.log("Lite impl exists:", expected);
        }

        console.log("Lite impl:", expected);
        vm.stopBroadcast();
    }
}


