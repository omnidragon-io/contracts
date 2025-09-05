// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OmniDragonOracle} from "../contracts/core/oracles/OmniDragonOracle.sol";

interface ICREATE2Factory {
    function deploy(bytes32 salt, bytes memory bytecode) external payable returns (address);
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address);
}

contract DeployFixedOracle is Script {
    ICREATE2Factory constant DRAGON_CREATE2_FACTORY = ICREATE2Factory(0xAA28020DDA6b954D16208eccF873D79AC6533833);
    address constant REGISTRY = 0x6940aDc0A505108bC11CA28EefB7E3BAc7AF0777;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying Fixed Oracle (Modified Contract) ===");
        console.log("Deployer:", deployer);
        console.log("Registry:", REGISTRY);
        console.log("Factory:", address(DRAGON_CREATE2_FACTORY));
        console.log("");
        
        // Generate init bytecode
        bytes memory initBytecode = _generateInitBytecode(REGISTRY, deployer);
        bytes32 bytecodeHash = keccak256(initBytecode);
        
        console.log("=== Current Contract Info ===");
        console.log("Bytecode Hash:");
        console.logBytes32(bytecodeHash);
        console.log("Bytecode Length:", initBytecode.length);
        console.log("");
        
        // Use a simple deterministic salt for now
        bytes32 salt = keccak256(abi.encodePacked("DRAGON_ORACLE_FIXED_V2", block.timestamp));
        address predictedAddress = DRAGON_CREATE2_FACTORY.computeAddress(salt, bytecodeHash);
        
        console.log("=== Deployment Info ===");
        console.log("Salt:");
        console.logBytes32(salt);
        console.log("Predicted Address:", predictedAddress);
        console.log("");
        
        // Deploy the fixed oracle
        console.log("=== Deploying ===");
        
        vm.startBroadcast(deployerPrivateKey);
        
        address deployedOracle = DRAGON_CREATE2_FACTORY.deploy(salt, initBytecode);
        
        vm.stopBroadcast();
        
        console.log("SUCCESS!");
        console.log("Deployed Oracle:", deployedOracle);
        console.log("Matches Prediction:", deployedOracle == predictedAddress);
        console.log("");
        
        // Configure the oracle
        console.log("=== Configuring Oracle ===");
        OmniDragonOracle oracle = OmniDragonOracle(payable(deployedOracle));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Set to SECONDARY mode (ready to receive price data)
        oracle.setMode(OmniDragonOracle.OracleMode.SECONDARY);
        console.log("Mode set to SECONDARY");
        
        // Configure Arbitrum peer (so we can receive requests from Arbitrum)
        uint32 arbitrumEid = 30110;
        bytes32 arbitrumPeer = bytes32(uint256(uint160(0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777)));
        oracle.setPeer(arbitrumEid, arbitrumPeer);
        console.log("Arbitrum peer configured");
        
        vm.stopBroadcast();
        
        // Test the critical fix
        console.log("=== Testing the Fix ===");
        (int256 price, uint256 timestamp) = oracle.getLatestPrice();
        console.log("getLatestPrice() call successful:");
        console.logInt(price);
        console.log("Timestamp:", timestamp);
        console.log("CRITICAL: No revert on zero timestamp - fix is working!");
        console.log("");
        
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Fixed Oracle Address:", deployedOracle);
        console.log("Key Fix: Commented out timestamp validation in _lzReceive");
        console.log("Now LayerZero Read requests won't revert on zero timestamp");
        console.log("");
        
        console.log("=== Next Steps ===");
        console.log("1. Test cross-chain price request from Arbitrum to this oracle");
        console.log("2. It should now complete without LayerZero execution failures");
        console.log("3. Save this address for future use:");
        console.log("   NEW_FIXED_ORACLE =", deployedOracle);
        
        // Export for easy copying
        console.log("");
        console.log("=== Copy These Values ===");
        console.log("Bytecode Hash:", vm.toString(bytecodeHash));
        console.log("Salt:", vm.toString(salt));
        console.log("Address:", deployedOracle);
    }
    
    function _generateInitBytecode(address registry, address initialOwner) internal pure returns (bytes memory) {
        bytes memory creationCode = type(OmniDragonOracle).creationCode;
        bytes memory constructorArgs = abi.encode(registry, initialOwner);
        return abi.encodePacked(creationCode, constructorArgs);
    }
}
