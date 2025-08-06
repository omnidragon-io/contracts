// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

contract DeployOmniDragonRegistry is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== OMNIDRAGON REGISTRY DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy OmniDragonRegistry with deployer as initial owner
        OmniDragonRegistry registry = new OmniDragonRegistry(deployer);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("Registry Address:", address(registry));
        console.log("Owner:", registry.owner());
        console.log("Chain ID:", registry.getCurrentChainId());
        
        // Verify deployment
        require(registry.owner() == deployer, "Owner mismatch");
        require(registry.getCurrentChainId() == block.chainid, "Chain ID mismatch");
        
        console.log("");
        console.log("VERIFICATION PASSED");
        console.log("Registry ready for LayerZero V2 configuration!");
    }
}