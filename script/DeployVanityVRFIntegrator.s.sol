// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/vrf/ChainlinkVRFIntegratorV2_5.sol";

contract DeployVanityVRFIntegrator is Script {
    // VANITY ADDRESS: 0x69...3777 (from vanity generator)
    bytes32 constant VANITY_SALT = 0x2842410312732723c81fb6b53a245123933b7d4351f97d5495b1c5c9a4a96c02;
    address constant EXPECTED_ADDRESS = 0x69d68432A3b84c1E0EDda982d2e13aef28ac3777;
    
    // Registry address (same across all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // Create2Factory with Ownership
    address constant OMNI_CREATE2_FACTORY = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== VANITY VRF INTEGRATOR DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Registry Address:", REGISTRY_ADDRESS);
        console.log("Expected VRF Address:", EXPECTED_ADDRESS);
        console.log("Salt:", vm.toString(VANITY_SALT));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get bytecode with constructor args (registry address)
        bytes memory bytecode = abi.encodePacked(
            type(ChainlinkVRFIntegratorV2_5).creationCode,
            abi.encode(REGISTRY_ADDRESS)
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
        
        // Deploy using CREATE2FactoryWithOwnership
        (bool success, bytes memory returnData) = OMNI_CREATE2_FACTORY.call(
            abi.encodeWithSignature("deploy(bytes,bytes32,string)", bytecode, VANITY_SALT, "ChainlinkVRFIntegratorV2_5")
        );
        
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                revert("Factory deployment failed with no reason");
            }
        }
        
        // Get the deployed VRF integrator instance
        ChainlinkVRFIntegratorV2_5 vrfIntegrator = ChainlinkVRFIntegratorV2_5(payable(actualAddress));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("VRF Integrator Address:", address(vrfIntegrator));
        console.log("Owner:", vrfIntegrator.owner());
        console.log("Registry:", address(vrfIntegrator.registry()));
        console.log("Endpoint:", address(vrfIntegrator.endpoint()));
        console.log("Request Counter:", vrfIntegrator.requestCounter());
        
        // Verify deployment
        require(vrfIntegrator.owner() == deployer, "Owner mismatch");
        require(address(vrfIntegrator.registry()) == REGISTRY_ADDRESS, "Registry mismatch");
        require(address(vrfIntegrator) == actualAddress, "Address mismatch");
        
        console.log("Final deployed address:", address(vrfIntegrator));
        
        // Pattern check for 0x69...3777
        uint160 addrInt = uint160(address(vrfIntegrator));
        bool startsWithSix = (addrInt >> 152) == 0x69; // Check first byte
        bool endsWithThree = (addrInt & 0xFFFF) == 0x3777; // Check last 2 bytes
        
        console.log("Pattern check: starts with 0x69?", startsWithSix ? "YES" : "NO");
        console.log("Pattern check: ends with 3777?", endsWithThree ? "YES" : "NO");
        console.log("Perfect vanity address?", (startsWithSix && endsWithThree) ? "YES!" : "NO");
        
        console.log("");
        console.log("VERIFICATION PASSED");
        console.log("VRF Integrator ready for LayerZero V2 configuration!");
        
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Deploy on all chains (Sonic, Arbitrum, Ethereum, Base, Avalanche, BSC)");
        console.log("2. Set up LayerZero peers between chains");
        console.log("3. Configure messaging pathways");
        console.log("4. Update layerzero.config.ts with new addresses");
    }
}