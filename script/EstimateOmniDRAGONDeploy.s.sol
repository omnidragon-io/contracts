// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/tokens/omniDRAGON.sol";

contract EstimateOmniDragon is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.envOr("TOKEN_OWNER", vm.addr(pk));
        address delegate = owner;
        address registry = vm.envOr("REGISTRY_ADDRESS", address(0x6949936442425f4137807Ac5d269e6Ef66d50777));

        vm.startBroadcast(pk);
        omniDRAGON token = new omniDRAGON("Dragon", "DRAGON", delegate, registry, owner);
        vm.stopBroadcast();

        console.log("omniDRAGON deployed at:", address(token));
    }
}


