// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistryLite.sol";

contract DeployRegistryLiteImpl is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("REGISTRY_OWNER", vm.addr(pk));

        vm.startBroadcast(pk);
        OmniDragonRegistryLite impl = new OmniDragonRegistryLite(owner);
        vm.stopBroadcast();

        console.log("OmniDragonRegistryLite deployed at:", address(impl));
        console.log("Owner:", owner);
        console.log("ChainId:", block.chainid);
    }
}


