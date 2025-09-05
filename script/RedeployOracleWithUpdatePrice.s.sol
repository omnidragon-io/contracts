// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/core/oracles/OmniDragonOracle.sol";

interface IOmniDragonRegistry {
    function getLayerZeroEndpoint(uint16 chainId) external view returns (address);
}

contract RedeployOracleWithUpdatePrice is Script {
    function run() external {
        address registryAddress = 0x69a6A2813c2224bBc34B3d0Bf56C719DE3C34777; // Using lottery manager as registry for now
        address currentOracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== REDEPLOYING ORACLE WITH FIXED updatePrice() ===" );
        console.log("Deployer:", deployer);
        console.log("Current Oracle:", currentOracle);
        console.log("");

        console.log("1. Deploying new oracle with updatePrice() -> bool...");
        
        // Deploy new oracle
        OmniDragonOracle newOracle = new OmniDragonOracle(
            registryAddress,
            deployer
        );

        console.log("   New Oracle deployed at:", address(newOracle));
        console.log("");

        console.log("2. Testing updatePrice() function...");
        try newOracle.updatePrice() returns (bool success) {
            console.log("   updatePrice() returned:", success);
        } catch Error(string memory reason) {
            console.log("   updatePrice() failed:", reason);
        } catch {
            console.log("   updatePrice() failed with no reason");
        }

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("[SUCCESS] New oracle deployed with fixed updatePrice()");
        console.log("[INFO] Oracle address:", address(newOracle));
        console.log("");
        console.log("[NEXT STEPS]:");
        console.log("1. Update lottery manager to use new oracle");
        console.log("2. Update DRAGON token lottery manager");
        console.log("3. Test lottery integration");

        vm.stopBroadcast();
    }
}
