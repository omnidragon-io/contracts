const { ethers } = require('hardhat');

async function setArbitrumPriceManually() {
    console.log("🔧 Manually setting Arbitrum Oracle price for LayerZero Read...\n");

    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    const oracle = await ethers.getContractAt("OmniDragonOracle", oracleAddress);
    const [signer] = await ethers.getSigners();
    
    console.log(`📄 Oracle: ${oracleAddress}`);
    console.log(`💳 Signer: ${signer.address}\n`);
    
    try {
        // Check current state
        const mode = await oracle.mode();
        const priceInitialized = await oracle.priceInitialized();
        const owner = await oracle.owner();
        
        console.log(`Mode: ${mode} (1=PRIMARY, 2=SECONDARY)`);
        console.log(`Price Initialized: ${priceInitialized}`);
        console.log(`Owner: ${owner}\n`);
        
        if (signer.address.toLowerCase() !== owner.toLowerCase()) {
            throw new Error("Not the owner!");
        }
        
        // Strategy: Switch to SECONDARY mode and manually initialize values
        console.log("=== 🚀 Manual Fix ===");
        
        if (mode !== 2) {
            console.log("Step 1: Setting mode to SECONDARY...");
            const tx = await oracle.setMode(2);
            await tx.wait();
            console.log("✅ Mode set to SECONDARY");
        }
        
        // In SECONDARY mode, we need to manually set the state variables
        // Since we can't directly write to private vars, let's use a different approach
        
        // The issue is getLatestPrice() returns (0, 0) when not initialized
        // Let's check the contract's latestPrice and lastUpdateTime storage
        
        console.log("Step 2: Checking current storage values...");
        const latestPrice = await oracle.latestPrice();
        const lastUpdateTime = await oracle.lastUpdateTime();
        const priceInit = await oracle.priceInitialized();
        
        console.log(`   latestPrice: ${latestPrice.toString()}`);
        console.log(`   lastUpdateTime: ${lastUpdateTime.toString()}`);
        console.log(`   priceInitialized: ${priceInit}`);
        
        // The oracle needs to be initialized with some price data
        // Let's try a simple approach: check if there are any admin functions
        // we can use to bootstrap the oracle
        
        if (!priceInit || latestPrice.eq(0) || lastUpdateTime.eq(0)) {
            console.log("\nStep 3: Manual initialization required...");
            console.log("❌ Oracle state variables are not accessible via external functions");
            console.log("💡 Solution: Deploy a new oracle with proper initialization");
            console.log("   OR configure oracle sources and pair in PRIMARY mode");
            console.log("   OR use a different approach...");
            
            // Alternative: Create a mock response for testing
            console.log("\n🔄 Alternative: Set realistic price values manually...");
            
            // Try to find writable functions that could help
            try {
                // Check if there are any setter functions we missed
                const currentTime = Math.floor(Date.now() / 1000);
                const mockPrice = ethers.utils.parseUnits("0.000296", 18); // Example price
                
                console.log(`Attempting to set mock price: ${mockPrice.toString()}`);
                console.log(`Current timestamp: ${currentTime}`);
                
                // Unfortunately, there don't seem to be direct setter functions
                // The only way to set the price is through updatePrice() which requires full setup
                
            } catch (error) {
                console.log(`Cannot set price directly: ${error.message}`);
            }
        }
        
        // Final verification
        const finalPrice = await oracle.getLatestPrice();
        console.log(`\n🔍 Final check:`);
        console.log(`   Price: ${finalPrice.price.toString()}`);
        console.log(`   Timestamp: ${finalPrice.timestamp.toString()}`);
        
        if (finalPrice.timestamp.gt(0)) {
            console.log("🎉 SUCCESS! Oracle has valid price data");
        } else {
            console.log("❌ Oracle still returns zero timestamp");
            console.log("\n💡 WORKAROUND: Modify the oracle contract to return mock data");
            console.log("   or configure the oracle sources properly in PRIMARY mode");
        }
        
    } catch (error) {
        console.error("❌ Error:", error.message);
    }
}

setArbitrumPriceManually().catch(console.error);
