const { ethers } = require('hardhat');

async function fixArbitrumOracle() {
    console.log("🔧 Fixing Arbitrum Oracle using Hardhat...\n");

    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    
    // Get the deployed contract
    const oracle = await ethers.getContractAt("OmniDragonOracle", oracleAddress);
    const [signer] = await ethers.getSigners();
    
    console.log(`📄 Oracle: ${oracleAddress}`);
    console.log(`💳 Signer: ${signer.address}\n`);
    
    try {
        // Check current state
        console.log("=== 📊 Current State ===");
        const mode = await oracle.mode();
        const priceInitialized = await oracle.priceInitialized();
        const emergencyMode = await oracle.emergencyMode();
        const owner = await oracle.owner();
        
        console.log(`Mode: ${mode} (0=UNINITIALIZED, 1=PRIMARY, 2=SECONDARY)`);
        console.log(`Price Initialized: ${priceInitialized}`);
        console.log(`Emergency Mode: ${emergencyMode}`);
        console.log(`Owner: ${owner}`);
        
        if (signer.address.toLowerCase() !== owner.toLowerCase()) {
            throw new Error(`Not the owner! Oracle owner is ${owner}`);
        }
        
        if (emergencyMode) {
            throw new Error("Oracle is in emergency mode");
        }
        
        // Get current price data
        const currentPrice = await oracle.getLatestPrice();
        console.log(`Current Price: ${currentPrice.price.toString()}`);
        console.log(`Current Timestamp: ${currentPrice.timestamp.toString()}\n`);
        
        // Fix: Set to PRIMARY and update price
        console.log("=== 🚀 Fixing Oracle ===");
        
        let needsModeChange = mode !== 1;
        let needsPriceUpdate = !priceInitialized || currentPrice.timestamp.eq(0);
        
        if (needsModeChange) {
            console.log("Step 1: Setting mode to PRIMARY...");
            const tx = await oracle.setMode(1);
            await tx.wait();
            console.log("✅ Mode set to PRIMARY");
        }
        
        if (needsPriceUpdate) {
            console.log("Step 2: Updating price...");
            const tx = await oracle.updatePrice();
            const receipt = await tx.wait();
            console.log("✅ Price updated");
            
            // Parse events
            receipt.events?.forEach((event) => {
                if (event.event === 'PriceUpdated') {
                    console.log(`📊 Dragon Price: ${event.args.dragonPrice.toString()}`);
                    console.log(`📊 Native Price: ${event.args.nativePrice.toString()}`);
                    console.log(`📊 Timestamp: ${event.args.timestamp.toString()}`);
                }
            });
        }
        
        // Switch back to SECONDARY
        if (needsModeChange) {
            console.log("Step 3: Switching back to SECONDARY...");
            const tx = await oracle.setMode(2);
            await tx.wait();
            console.log("✅ Mode set to SECONDARY");
        }
        
        // Final verification
        console.log("\n=== ✅ Verification ===");
        const finalPrice = await oracle.getLatestPrice();
        console.log(`Final Price: ${finalPrice.price.toString()}`);
        console.log(`Final Timestamp: ${finalPrice.timestamp.toString()}`);
        
        if (finalPrice.timestamp.gt(0)) {
            const date = new Date(finalPrice.timestamp.toNumber() * 1000);
            console.log(`Date: ${date.toISOString()}`);
            console.log("\n🎉 SUCCESS! Arbitrum oracle is now initialized!");
            console.log("🔄 You can now retry the LayerZero cross-chain price request");
        } else {
            console.log("❌ Still returning zero timestamp");
        }
        
    } catch (error) {
        console.error("❌ Error:", error.message);
        if (error.reason) console.error("Reason:", error.reason);
    }
}

// Execute if called directly
if (require.main === module) {
    fixArbitrumOracle()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { fixArbitrumOracle };
