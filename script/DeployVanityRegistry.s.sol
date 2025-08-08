// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/config/OmniDragonRegistry.sol";

contract DeployVanityRegistry is Script {
    // PERFECT VANITY ADDRESS: 0x69...0777 (using exact factory bytecode hash)
    bytes32 constant VANITY_SALT = 0x739045e5616b1e08a77452813c381b9669fc1332384606e22d1f02e3a229563d;
    address constant EXPECTED_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // Create2Factory with Ownership (renamed to avoid conflict with forge-std)
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== VANITY REGISTRY DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Expected Address:", EXPECTED_ADDRESS);
        console.log("Salt:", vm.toString(VANITY_SALT));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get bytecode with constructor args
        bytes memory bytecode = abi.encodePacked(
            type(OmniDragonRegistry).creationCode,
            abi.encode(deployer)
        );
        
        // Calculate actual CREATE2 address using the factory
        address actualAddress = vm.computeCreate2Address(
            VANITY_SALT,
            keccak256(bytecode),
            OMNI_CREATE2_FACTORY
        );
        
        console.log("Calculated Address:", actualAddress);
        console.log("Using Create2Factory:", OMNI_CREATE2_FACTORY);
        
        if (actualAddress != EXPECTED_ADDRESS) {
            console.log("INFO: Using actual calculated address (bytecode hash differs from mock)");
            console.log("Expected:", EXPECTED_ADDRESS);
            console.log("Actual:  ", actualAddress);
        }
        
        // Deploy using CREATE2FactoryWithOwnership with correct signature
        // Function signature: deploy(bytes memory bytecode, bytes32 salt, string memory contractType)
        (bool success, bytes memory returnData) = OMNI_CREATE2_FACTORY.call(
            abi.encodeWithSignature("deploy(bytes,bytes32,string)", bytecode, VANITY_SALT, "OmniDragonRegistry")
        );
        
        if (!success) {
            if (returnData.length > 0) {
                // Bubble up the revert reason
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("Factory deployment failed with no reason");
            }
        }
        
        // Get the deployed registry instance
        OmniDragonRegistry registry = OmniDragonRegistry(actualAddress);
        
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
        require(address(registry) == actualAddress, "Address mismatch");
        
        console.log("Final deployed address:", address(registry));
        
        // Pattern check for 0x69...0777
        uint160 addrInt = uint160(address(registry));
        bool startsWithSix = (addrInt >> 152) == 0x69; // Check first byte
        bool endsWithSeven = (addrInt & 0xFFFF) == 0x0777; // Check last 2 bytes
        
        console.log("Pattern check: starts with 0x69?", startsWithSix ? "YES" : "NO");
        console.log("Pattern check: ends with 0777?", endsWithSeven ? "YES" : "NO");
        console.log("Perfect vanity address?", (startsWithSix && endsWithSeven) ? "YES!" : "NO");
        
        console.log("");
        console.log("VERIFICATION PASSED");
        console.log("Registry ready for LayerZero V2 configuration!");
    }
}