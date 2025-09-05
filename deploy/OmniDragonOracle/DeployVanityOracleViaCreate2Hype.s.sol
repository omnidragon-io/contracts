// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../contracts/core/oracles/OmniDragonOracle.sol";

interface ICREATE2Factory {
    function deploy(bytes memory bytecode, bytes32 salt, string memory contractType) external returns (address);
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address);
}

contract DeployVanityOracleViaCreate2Hype is Script {
    
    address constant FACTORY_ADDRESS = 0xAA28020DDA6b954D16208eccF873D79AC6533833;
    address constant HYPERLIQUID_LAYERZERO_ENDPOINT = 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9;
    
    // Vanity address result from oracle-vanity-generator (LAYERZERO READ ENABLED v2 - FIXED)
    bytes32 constant VANITY_SALT = 0x4144cf945e8a6d9383baee6860da016616be853115156198ef501bccc8f6dc02;
    address constant EXPECTED_ADDRESS = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYING VANITY ORACLE VIA CREATE2 ON HYPERLIQUID ===");
        console.log("Factory:", FACTORY_ADDRESS);
        console.log("LayerZero Endpoint:", HYPERLIQUID_LAYERZERO_ENDPOINT);
        console.log("Deployer:", deployer);
        console.log("Expected address:", EXPECTED_ADDRESS);
        console.log("Vanity salt:");
        console.logBytes32(VANITY_SALT);
        console.log("");
        
        // Get the creation bytecode with constructor arguments (using LayerZero endpoint directly)
        bytes memory creationCode = type(OmniDragonOracle).creationCode;
        bytes memory constructorArgs = abi.encode(HYPERLIQUID_LAYERZERO_ENDPOINT, deployer);
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
            console.log("Expected:", EXPECTED_ADDRESS);
            console.log("Computed:", computedAddress);
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying via CREATE2 factory...");
        
        // Deploy the contract
        address deployedAddress = ICREATE2Factory(FACTORY_ADDRESS).deploy(
            initCode,
            VANITY_SALT,
            "OmniDragonOracle"
        );
        
        vm.stopBroadcast();
        
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Deployed address:", deployedAddress);
        console.log("Expected address:", EXPECTED_ADDRESS);
        
        if (deployedAddress == EXPECTED_ADDRESS) {
            console.log("SUCCESS: Vanity address achieved!");
        } else {
            console.log("ERROR: Address mismatch!");
        }
        
        console.log("");
        console.log("Next steps:");
        console.log("1. Set oracle mode to SECONDARY (2)");
        console.log("2. Configure LayerZero peers");
        console.log("3. Set enforced options");
        console.log("4. Test cross-chain functionality");
    }
}
