const { ethers } = require('hardhat');

async function initializeOracleNetwork() {
    console.log("🌐 Initializing Oracle Network: PRIMARY → SECONDARY flow...\n");

    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    
    // Step 1: Check current state of both oracles
    console.log("=== 📊 Current Network State ===");
    
    // Sonic oracle (we'll make this PRIMARY)
    console.log("🔍 Checking Sonic oracle...");
    const sonicOracle = await ethers.getContractAt("OmniDragonOracle", oracleAddress);
    
    const sonicMode = await sonicOracle.mode();
    const sonicPriceInit = await sonicOracle.priceInitialized();
    const sonicPrice = await sonicOracle.getLatestPrice();
    
    console.log(`   Sonic - Mode: ${sonicMode}, Price Init: ${sonicPriceInit}`);
    console.log(`   Sonic - Price: ${sonicPrice.price.toString()}, TS: ${sonicPrice.timestamp.toString()}`);
    
    // We can't easily check Arbitrum from this script, but we know it's SECONDARY with priceInitialized=false
    console.log(`   Arbitrum - Mode: 2 (SECONDARY), Price Init: false (known issue)`);
    
    console.log("\n=== 🎯 Solution: PRIMARY → SECONDARY Architecture ===");
    console.log("1. Set Sonic as PRIMARY with configured oracle sources");
    console.log("2. Initialize Sonic oracle with updatePrice()");  
    console.log("3. Send price data from Sonic to Arbitrum");
    console.log("4. Arbitrum receives data and becomes priceInitialized=true");
    console.log("5. Now Arbitrum can respond to LayerZero Read requests");
    
    try {
        // Step 2: Set up Sonic as PRIMARY (if not already)
        if (sonicMode !== 1) {
            console.log("\n🚀 Step 1: Setting Sonic to PRIMARY mode...");
            const tx = await sonicOracle.setMode(1);
            await tx.wait();
            console.log("✅ Sonic is now PRIMARY");
        } else {
            console.log("\n✅ Sonic is already PRIMARY");
        }
        
        // Step 3: Check if Sonic needs price initialization
        if (!sonicPriceInit || sonicPrice.timestamp.eq(0)) {
            console.log("\n📈 Step 2: Sonic needs price initialization");
            console.log("⚠️  This requires configured oracle sources (Chainlink, Band, etc.)");
            console.log("💡 For testing, we can manually set a price or use the timestamp fix");
            
            // For demo purposes, let's show what the proper setup would be:
            console.log("\n🔧 Proper Setup (for production):");
            console.log("   // Configure Band Protocol");
            console.log("   await oracle.setPushOracle(2, true, 100, 3600, bandAddress, 'S');");
            console.log("   ");
            console.log("   // Or configure Chainlink");  
            console.log("   await oracle.setPullOracle(0, true, 100, 3600, chainlinkFeed, priceId);");
            console.log("   ");
            console.log("   // Then initialize");
            console.log("   await oracle.updatePrice();");
            
        } else {
            console.log("\n✅ Sonic oracle is already initialized");
        }
        
        // Step 4: Send price data to Arbitrum oracle
        console.log("\n📡 Step 3: Send price data to Arbitrum...");
        
        // This is the reverse direction - Sonic (PRIMARY) sends to Arbitrum (SECONDARY)
        const arbitrumEid = 30110;
        
        // Check if Arbitrum is configured as peer
        const isArbitrumPeer = await sonicOracle.activePeers(arbitrumEid);
        console.log(`   Arbitrum peer configured: ${isArbitrumPeer}`);
        
        if (isArbitrumPeer) {
            console.log("   Ready to send price data to Arbitrum!");
            console.log("   This would initialize the Arbitrum oracle");
            console.log("   After that, Arbitrum could respond to our original LayerZero Read requests");
        } else {
            console.log("   ⚠️  Arbitrum peer not configured for reverse direction");
        }
        
        // Step 5: Show the complete picture
        console.log("\n=== 🎊 Complete Oracle Network ===");
        console.log("┌─────────────────────────────────────────┐");
        console.log("│            Oracle Network               │");
        console.log("│                                         │");
        console.log("│  Sonic (PRIMARY)     ←→   Arbitrum     │");
        console.log("│  - Has oracle sources    (SECONDARY)    │"); 
        console.log("│  - Calls updatePrice()   - Receives     │");
        console.log("│  - Sends data →            price data   │");
        console.log("│                          - Now can      │");
        console.log("│                            respond to   │");
        console.log("│                            LayerZero    │");
        console.log("│                            Read         │");
        console.log("└─────────────────────────────────────────┘");
        
        console.log("\n💡 Next Actions:");
        console.log("1. Configure oracle sources on Sonic PRIMARY");
        console.log("2. Call updatePrice() to initialize Sonic");
        console.log("3. Send initialized price data to Arbitrum"); 
        console.log("4. Now Arbitrum can respond to LayerZero Read requests!");
        console.log("5. Our original cross-chain price request will work");
        
        return true;
        
    } catch (error) {
        console.error("❌ Error:", error.message);
        return false;
    }
}

// Utility function to demonstrate the reverse direction
async function sendPriceToArbitrum() {
    console.log("\n📤 Sending price data from Sonic to Arbitrum...");
    
    const sonicOracle = await ethers.getContractAt("OmniDragonOracle", "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777");
    const arbitrumEid = 30110;
    
    try {
        // Quote fee for reverse direction
        const fee = await sonicOracle.quoteFee(arbitrumEid, "0x");
        console.log(`   Fee: ${ethers.utils.formatEther(fee.nativeFee)} S`);
        
        // Send price data (this would initialize Arbitrum oracle)
        const tx = await sonicOracle.requestPrice(arbitrumEid, "0x", {
            value: fee.nativeFee
        });
        
        console.log(`   Transaction: ${tx.hash}`);
        const receipt = await tx.wait();
        
        if (receipt.status === 1) {
            console.log("✅ Price data sent to Arbitrum!");
            console.log("   This should initialize the Arbitrum oracle");
            console.log("   Now Arbitrum can respond to LayerZero Read requests");
        }
        
    } catch (error) {
        console.log(`❌ Failed to send: ${error.message}`);
    }
}

// Execute if called directly
if (require.main === module) {
    initializeOracleNetwork()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { initializeOracleNetwork, sendPriceToArbitrum };
