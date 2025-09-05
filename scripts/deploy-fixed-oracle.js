const { ethers } = require('hardhat');

async function deployFixedOracle() {
    console.log("🚀 Deploying fixed OmniDragonOracle to Sonic...\n");

    const [deployer] = await ethers.getSigners();
    console.log(`📱 Deploying with account: ${deployer.address}`);
    
    // Check balance
    const balance = await deployer.getBalance();
    console.log(`💰 Balance: ${ethers.utils.formatEther(balance)} S\n`);
    
    try {
        // Get the registry address (needed for constructor)
        const registryAddress = "0x6940aDc0A505108bC11CA28EefB7E3BAc7AF0777"; // Sonic registry
        
        console.log("📄 Deploying OmniDragonOracle...");
        console.log(`   Registry: ${registryAddress}`);
        console.log(`   Owner: ${deployer.address}\n`);
        
        // Deploy the oracle
        const OracleFactory = await ethers.getContractFactory("OmniDragonOracle");
        const oracle = await OracleFactory.deploy(registryAddress, deployer.address, {
            gasLimit: 3000000
        });
        
        console.log(`⏳ Transaction: ${oracle.deployTransaction.hash}`);
        console.log("   Waiting for deployment...");
        
        await oracle.deployed();
        
        console.log(`✅ OmniDragonOracle deployed at: ${oracle.address}`);
        console.log(`   Block: ${oracle.deployTransaction.blockNumber}`);
        console.log(`   Gas used: ${oracle.deployTransaction.gasLimit?.toString()}\n`);
        
        // Verify the deployment
        console.log("🔍 Verifying deployment...");
        const mode = await oracle.mode();
        const owner = await oracle.owner();
        const readChannel = await oracle.readChannel();
        
        console.log(`   Mode: ${mode} (2=SECONDARY)`);
        console.log(`   Owner: ${owner}`);
        console.log(`   Read Channel: ${readChannel}`);
        
        // Test getLatestPrice to make sure it doesn't revert
        const price = await oracle.getLatestPrice();
        console.log(`   Latest Price: ${price.price.toString()}, ${price.timestamp.toString()}`);
        
        console.log("\n🎉 Deployment successful!");
        console.log("📋 Next steps:");
        console.log(`   1. Set peer for Arbitrum: setPeer(30110, "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777")`);
        console.log(`   2. Update your requests to use new address: ${oracle.address}`);
        console.log(`   3. Test cross-chain price request`);
        
        return oracle.address;
        
    } catch (error) {
        console.error("❌ Deployment failed:");
        console.error(error.message);
        if (error.reason) console.error("Reason:", error.reason);
        throw error;
    }
}

// Execute if called directly
if (require.main === module) {
    deployFixedOracle()
        .then((address) => {
            console.log(`\n📍 New Oracle Address: ${address}`);
            process.exit(0);
        })
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { deployFixedOracle };
