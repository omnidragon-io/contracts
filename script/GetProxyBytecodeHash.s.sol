// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistryProxy.sol";

contract GetProxyBytecodeHash is Script {
    function run() external view {
        address impl = vm.envAddress("REGISTRY_IMPL");
        require(impl != address(0), "REGISTRY_IMPL=0");

        bytes memory initCode = abi.encodePacked(
            type(OmniDragonRegistryProxy).creationCode,
            abi.encode(impl)
        );

        bytes32 hash = keccak256(initCode);
        console.log("REGISTRY_IMPL:", impl);
        console.log("Proxy bytecode length:", initCode.length);
        console.log("Proxy bytecode hash:", vm.toString(hash));
        console.log("CREATE2Factory:", 0xAA28020DDA6b954D16208eccF873D79AC6533833);
        console.log("Use vanity-generator with:");
        console.log("  --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833");
        console.log("  --bytecode-hash", vm.toString(hash));
    }
}


