const { ethers } = require('hardhat');

async function setupPrimaryOracle() {
    console.log("🔧 Setting up PRIMARY oracle to initialize SECONDARY oracles...\n");

    // We'll use Sonic as PRIMARY since it's where we have the most control
    const sonicOracle = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    
    console.log(`📄 Configuring Sonic oracle as PRIMARY: ${sonicOracle}`);
    
    try {
        // Get the oracle contract
        const oracle = await ethers.getContractAt("OmniDragonOracle", sonicOracle);
        const [signer] = await ethers.getSigners();
        
        console.log(`💳 Signer: ${signer.address}`);
        
        // Check current state
        const mode = await oracle.mode();
        const priceInitialized = await oracle.priceInitialized();
        const emergencyMode = await oracle.emergencyMode();
        
        console.log(`\n=== 📊 Current State ===`);
        console.log(`Mode: ${mode} (0=UNINITIALIZED, 1=PRIMARY, 2=SECONDARY)`);
        console.log(`Price Initialized: ${priceInitialized}`);
        console.log(`Emergency Mode: ${emergencyMode}`);
        
        if (emergencyMode) {
            throw new Error("Oracle is in emergency mode");
        }
        
        // Step 1: Configure minimal oracle sources for PRIMARY mode
        console.log(`\n=== 🚀 Step 1: Setting up PRIMARY mode ===`);
        
        if (mode !== 1) {
            console.log("Setting mode to PRIMARY...");
            const tx = await oracle.setMode(1);
            await tx.wait();
            console.log("✅ Mode set to PRIMARY");
        } else {
            console.log("✅ Already in PRIMARY mode");
        }
        
        // Step 2: Configure oracle sources (we need at least one working oracle source)
        console.log(`\n=== 📡 Step 2: Configure Oracle Sources ===`);
        
        // Try to configure a Chainlink oracle source if available
        // For Sonic, we might need to use Band Protocol or create mock data
        
        // Let's check what oracle sources are already configured
        const chainlinkConfig = await oracle.getOracleConfig(0); // CHAINLINK_NATIVE_USD
        const pythConfig = await oracle.getOracleConfig(1);      // PYTH_NATIVE_USD  
        const bandConfig = await oracle.getOracleConfig(2);      // BAND_NATIVE_USD
        const api3Config = await oracle.getOracleConfig(3);      // API3_NATIVE_USD
        
        console.log(`Chainlink active: ${chainlinkConfig.isActive}`);
        console.log(`Pyth active: ${pythConfig.isActive}`);
        console.log(`Band active: ${bandConfig.isActive}`);
        console.log(`API3 active: ${api3Config.isActive}`);
        
        // Check if any sources are configured
        const hasActiveSources = chainlinkConfig.isActive || pythConfig.isActive || 
                                bandConfig.isActive || api3Config.isActive;
        
        if (!hasActiveSources) {
            console.log("\n⚠️  No oracle sources configured. Setting up Band Protocol...");
            
            // Band Protocol is often available on most chains
            // Sonic Band Protocol contract (if available)
            const bandAddress = "0x..."; // We'd need the actual Band contract address for Sonic
            
            console.log("📝 For production, you need to:");
            console.log("   1. Get Band Protocol contract address for Sonic");
            console.log("   2. Configure with: setPushOracle(2, true, 100, 3600, bandAddress, 'S')");
            console.log("   3. Or use API3/Chainlink if available");
            
            // For now, let's try to manually set a reasonable price for testing
            console.log("\n🧪 Setting test price manually...");
            
            // We need to directly set the oracle state - let's try a different approach
            // Since updatePrice() needs configured sources, let's configure at least one mock source
        }
        
        // Step 3: Try to update price
        console.log(`\n=== 📈 Step 3: Initialize Price ===`);
        
        try {
            console.log("Attempting updatePrice()...");
            const updateTx = await oracle.updatePrice();
            const receipt = await updateTx.wait();
            console.log("✅ Price updated successfully!");
            
            // Check for events
            receipt.events?.forEach((event) => {
                if (event.event === 'PriceUpdated') {
                    console.log(`📊 Dragon Price: ${event.args.dragonPrice.toString()}`);
                    console.log(`📊 Native Price: ${event.args.nativePrice.toString()}`);
                    console.log(`📊 Timestamp: ${event.args.timestamp.toString()}`);
                }
            });
            
        } catch (error) {
            console.log(`❌ updatePrice() failed: ${error.message}`);
            console.log("\n💡 Alternative: Manual price initialization needed");
            console.log("   This requires either:");
            console.log("   1. Configuring proper oracle sources");
            console.log("   2. Setting up a trading pair for TWAP");
            console.log("   3. Receiving price data from another PRIMARY oracle");
        }
        
        // Step 4: Check final state and send data to Arbitrum
        console.log(`\n=== 🔍 Step 4: Verification ===`);
        
        const finalPrice = await oracle.getLatestPrice();
        console.log(`Final Price: ${finalPrice.price.toString()}`);
        console.log(`Final Timestamp: ${finalPrice.timestamp.toString()}`);
        
        if (finalPrice.timestamp.gt(0)) {
            console.log("🎉 SUCCESS! Oracle is now initialized");
            
            // Now we can send this price data to Arbitrum oracle
            console.log(`\n=== 📡 Step 5: Initialize Arbitrum Oracle ===`);
            console.log("Now that Sonic oracle is initialized, we can:");
            console.log("1. Send price data from Sonic to Arbitrum");
            console.log("2. This will initialize the Arbitrum oracle");
            console.log("3. Then Arbitrum can respond to LayerZero Read requests");
            
            return true;
        } else {
            console.log("❌ Oracle still not initialized");
            return false;
        }
        
    } catch (error) {
        console.error("❌ Error setting up PRIMARY oracle:");
        console.error(error.message);
        return false;
    }
}

// Execute if called directly
if (require.main === module) {
    setupPrimaryOracle()
        .then((success) => {
            if (success) {
                console.log("\n🎊 PRIMARY oracle setup completed!");
            } else {
                console.log("\n❌ PRIMARY oracle setup failed");
            }
            process.exit(success ? 0 : 1);
        })
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { setupPrimaryOracle };
