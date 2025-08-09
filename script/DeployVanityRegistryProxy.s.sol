// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistryProxy.sol";

contract DeployVanityRegistryProxy is Script {
    // Vanity target address 0x69...0777 via salt; override with SALT_REGISTRY
    bytes32 constant DEFAULT_SALT = 0x739045e5616b1e08a77452813c381b9669fc1332384606e22d1f02e3a229563d;
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        address impl = vm.envAddress("REGISTRY_IMPL");
        require(impl != address(0), "REGISTRY_IMPL=0");
        bytes32 salt = vm.envOr("SALT_REGISTRY", DEFAULT_SALT);

        // Proxy init code
        bytes memory initCode = abi.encodePacked(
            type(OmniDragonRegistryProxy).creationCode,
            abi.encode(impl)
        );

        address expected = vm.computeCreate2Address(salt, keccak256(initCode), OMNI_CREATE2_FACTORY);
        console.log("Deploying Proxy vanity...");
        console.log("  Impl:", impl);
        console.log("  Salt:", vm.toString(salt));
        console.log("  Expected:", expected);

        if (expected.code.length == 0) {
            (bool ok, ) = OMNI_CREATE2_FACTORY.call(
                abi.encodeWithSignature("deploy(bytes,bytes32,string)", initCode, salt, "OmniDragonRegistryProxy")
            );
            require(ok, "Proxy deploy failed");
        } else {
            console.log("Proxy exists:", expected);
        }
        console.log("Proxy:", expected);

        vm.stopBroadcast();
    }
}


