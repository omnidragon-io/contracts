// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/core/oracles/OmniDragonOracle.sol";

interface ICREATE2Factory {
    function deploy(bytes memory bytecode, bytes32 salt, string memory contractType) external returns (address);
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address);
}

contract DeployVanityOracleViaCreate2 is Script {
    
    address constant FACTORY_ADDRESS = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    address constant REGISTRY_ADDRESS = 0x6940aDc0A505108bC11CA28EefB7E3BAc7AF0777;
    
    // Vanity address result from oracle-vanity-generator (LAYERZERO READ ENABLED v2 - FIXED)
    bytes32 constant VANITY_SALT = 0x4144cf945e8a6d9383baee6860da016616be853115156198ef501bccc8f6dc02;
    address constant EXPECTED_ADDRESS = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYING VANITY ORACLE VIA CREATE2 ===");
        console.log("Factory:", FACTORY_ADDRESS);
        console.log("Registry:", REGISTRY_ADDRESS);
        console.log("Deployer:", deployer);
        console.log("Expected address:", EXPECTED_ADDRESS);
        console.log("Vanity salt:");
        console.logBytes32(VANITY_SALT);
        console.log("");
        
        // Get the creation bytecode with constructor arguments
        bytes memory creationCode = type(OmniDragonOracle).creationCode;
        bytes memory constructorArgs = abi.encode(REGISTRY_ADDRESS, deployer);
        bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);
        bytes32 initCodeHash = keccak256(initCode);
        
        console.log("Init code hash:");
        console.logBytes32(initCodeHash);
        
        // Verify the computed address matches expected
        address computedAddress = ICREATE2Factory(FACTORY_ADDRESS).computeAddress(VANITY_SALT, initCodeHash);
        console.log("Computed address:", computedAddress);
        
        if (computedAddress != EXPECTED_ADDRESS) {
            console.log("WARNING: Computed address doesn't match expected!");
            console.log("This might be due to different constructor parameters.");
            console.log("Proceeding with computed address...");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy using CREATE2 factory
        console.log("Deploying via CREATE2 factory...");
        address deployedAddress = ICREATE2Factory(FACTORY_ADDRESS).deploy(
            initCode,
            VANITY_SALT,
            "OmniDragonOracle"
        );
        
        console.log("Oracle deployed at:", deployedAddress);
        
        // Configure the new oracle
        OmniDragonOracle oracle = OmniDragonOracle(payable(deployedAddress));
        
        // Set read channel (copy from old oracle if needed)
        console.log("Setting read channel...");
        oracle.setReadChannel(4294967295, true);  // Standard LayerZero Read Channel
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Vanity Oracle Address:", deployedAddress);
        console.log("Mode:", uint8(oracle.mode()));
        console.log("Read Channel:", oracle.readChannel());
        console.log("Owner:", oracle.owner());
        
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Update .env ORACLE_ADDRESS to:", deployedAddress);
        console.log("2. Set oracle mode (PRIMARY/SECONDARY) as needed");
        console.log("3. Configure peers on both chains");
        console.log("4. Update LayerZero config files");
    }
}
