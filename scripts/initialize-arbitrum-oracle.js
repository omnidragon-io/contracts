const { ethers } = require("ethers");
require('dotenv').config();

async function initializeArbitrumOracle() {
    console.log("🔧 Initializing Arbitrum Oracle to fix LayerZero Read...\n");

    // Connect to Arbitrum network
    const arbitrumProvider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL_ARBITRUM);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, arbitrumProvider);
    
    console.log(`🔗 Connected to Arbitrum`);
    console.log(`📄 Oracle: 0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777`);
    console.log(`💳 Wallet: ${wallet.address}\n`);

    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    
    // ABI for the functions we need
    const oracleAbi = [
        "function mode() external view returns (uint8)",
        "function priceInitialized() external view returns (bool)",
        "function emergencyMode() external view returns (bool)",
        "function setMode(uint8 newMode) external",
        "function updatePrice() external",
        "function getLatestPrice() external view returns (int256 price, uint256 timestamp)",
        "function owner() external view returns (address)",
        "event ModeChanged(uint8 oldMode, uint8 newMode)",
        "event PriceUpdated(int256 dragonPrice, int256 nativePrice, uint256 timestamp)"
    ];
    
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, wallet);
    
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
        console.log(`Our Address: ${wallet.address}\n`);
        
        if (wallet.address.toLowerCase() !== owner.toLowerCase()) {
            throw new Error(`Not the owner! Oracle owner is ${owner}`);
        }
        
        if (emergencyMode) {
            throw new Error("Oracle is in emergency mode - fix that first");
        }
        
        // Check wallet balance
        const balance = await wallet.getBalance();
        console.log(`Balance: ${ethers.utils.formatEther(balance)} ETH`);
        
        if (balance.lt(ethers.utils.parseEther("0.01"))) {
            throw new Error("Insufficient ETH balance for transactions");
        }
        
        // Strategy: Set to PRIMARY mode and call updatePrice
        console.log("\n=== 🚀 Fixing Oracle ===");
        
        if (mode !== 1) {
            console.log("Step 1: Setting mode to PRIMARY...");
            const setModeTx = await oracle.setMode(1, {
                gasLimit: 100000
            });
            console.log(`   Transaction: ${setModeTx.hash}`);
            await setModeTx.wait();
            console.log("   ✅ Mode set to PRIMARY");
        } else {
            console.log("✓ Already in PRIMARY mode");
        }
        
        if (!priceInitialized) {
            console.log("\nStep 2: Initializing price...");
            const updateTx = await oracle.updatePrice({
                gasLimit: 500000
            });
            console.log(`   Transaction: ${updateTx.hash}`);
            const receipt = await updateTx.wait();
            console.log("   ✅ Price update completed");
            
            // Check for PriceUpdated event
            receipt.logs.forEach((log) => {
                try {
                    const parsed = oracle.interface.parseLog(log);
                    if (parsed.name === 'PriceUpdated') {
                        console.log(`   📊 Price Updated Event:`);
                        console.log(`      Dragon Price: ${parsed.args.dragonPrice.toString()}`);
                        console.log(`      Native Price: ${parsed.args.nativePrice.toString()}`);
                        console.log(`      Timestamp: ${parsed.args.timestamp.toString()}`);
                    }
                } catch (e) {
                    // Not our event
                }
            });
        } else {
            console.log("✓ Price already initialized");
        }
        
        // Verify the fix
        console.log("\n=== ✅ Verification ===");
        const finalPrice = await oracle.getLatestPrice();
        console.log(`Final Price: ${finalPrice.price.toString()}`);
        console.log(`Final Timestamp: ${finalPrice.timestamp.toString()}`);
        
        if (finalPrice.timestamp.gt(0)) {
            const date = new Date(finalPrice.timestamp.toNumber() * 1000);
            console.log(`Date: ${date.toISOString()}`);
            console.log("🎉 SUCCESS! Oracle is now properly initialized");
            console.log("   LayerZero Read requests should now work!");
        } else {
            console.log("⚠️  Still returning zero timestamp - there may be other issues");
        }
        
        // Switch back to SECONDARY mode if desired
        console.log("\nStep 3: Switching back to SECONDARY mode...");
        const secondaryTx = await oracle.setMode(2, {
            gasLimit: 100000
        });
        console.log(`   Transaction: ${secondaryTx.hash}`);
        await secondaryTx.wait();
        console.log("   ✅ Mode set back to SECONDARY");
        
        // Final verification
        const finalModePrice = await oracle.getLatestPrice();
        console.log(`\nFinal verification:`);
        console.log(`   Price: ${finalModePrice.price.toString()}`);
        console.log(`   Timestamp: ${finalModePrice.timestamp.toString()}`);
        
        if (finalModePrice.timestamp.gt(0)) {
            console.log("🎊 PERFECT! Oracle is initialized and ready for LayerZero Read!");
        }
        
    } catch (error) {
        console.error("\n❌ Error initializing oracle:");
        console.error(error.message);
        
        if (error.reason) console.error("Reason:", error.reason);
        if (error.code) console.error("Code:", error.code);
    }
}

initializeArbitrumOracle().catch(console.error);
