const { ethers } = require('hardhat');

async function quickDeployFixedOracle() {
    console.log("🚀 Quick deploying fixed oracle to resolve LayerZero Read issue...\n");

    try {
        const [deployer] = await ethers.getSigners();
        console.log(`📱 Deploying with: ${deployer.address}`);
        
        const balance = await deployer.getBalance();
        console.log(`💰 Balance: ${ethers.utils.formatEther(balance)} S\n`);
        
        // Registry address from existing deployment
        const registryAddress = "0x6940aDc0A505108bC11CA28EefB7E3BAc7AF0777";
        
        console.log("📄 Deploying updated OmniDragonOracle...");
        console.log(`   Registry: ${registryAddress}`);
        console.log(`   This version has timestamp validation commented out\n`);
        
        const OracleFactory = await ethers.getContractFactory("OmniDragonOracle");
        const oracle = await OracleFactory.deploy(registryAddress, deployer.address);
        
        console.log(`⏳ Transaction: ${oracle.deployTransaction.hash}`);
        await oracle.deployed();
        
        console.log(`✅ New Oracle deployed at: ${oracle.address}`);
        console.log(`   Block: ${oracle.deployTransaction.blockNumber}\n`);
        
        // Configure the new oracle
        console.log("🔧 Configuring new oracle...");
        
        // Set to SECONDARY mode
        await oracle.setMode(2);
        console.log("✅ Mode set to SECONDARY");
        
        // Set up peer with Arbitrum
        const arbitrumEid = 30110;
        const arbitrumOracleBytes32 = "0x000000000000000000000000692e3212aaf12c715ca49e3e8ff909ca6a4f7777";
        
        await oracle.setPeer(arbitrumEid, arbitrumOracleBytes32);
        console.log(`✅ Arbitrum peer configured (EID: ${arbitrumEid})`);
        
        // Test the fixed oracle
        console.log("\n🧪 Testing the fix...");
        const testPrice = await oracle.getLatestPrice();
        console.log(`   getLatestPrice(): ${testPrice.price.toString()}, ${testPrice.timestamp.toString()}`);
        
        console.log("\n🎉 Fixed oracle deployed successfully!");
        console.log(`📍 New Oracle Address: ${oracle.address}`);
        console.log("\n📋 Next steps:");
        console.log("1. Update your scripts to use the new oracle address");
        console.log("2. Test cross-chain price request with new address");
        console.log("3. The timestamp validation issue should be resolved");
        
        return oracle.address;
        
    } catch (error) {
        console.error("\n❌ Deployment failed:");
        console.error(error.message);
        
        // Check if it's a known issue
        if (error.message.includes("gas")) {
            console.error("💡 Try increasing gas limit or gas price");
        } else if (error.message.includes("revert")) {
            console.error("💡 Check constructor parameters and network config");
        }
        
        throw error;
    }
}

// Execute if called directly
if (require.main === module) {
    quickDeployFixedOracle()
        .then((address) => {
            console.log(`\n🎊 Success! New Oracle: ${address}`);
            process.exit(0);
        })
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { quickDeployFixedOracle };
