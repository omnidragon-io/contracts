const { ethers } = require("ethers");
require('dotenv').config();

async function debugArbitrumOracle() {
    console.log("🔍 Debugging Arbitrum oracle to see why LayerZero Read is failing...\n");

    // Connect to Arbitrum network to check the source oracle
    const arbitrumProvider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL_ARBITRUM);
    
    console.log(`🔗 Connected to Arbitrum`);
    console.log(`📄 Arbitrum Oracle: 0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777\n`);

    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    
    // Basic ABI for the functions we need to check
    const oracleAbi = [
        "function getLatestPrice() external view returns (int256 price, uint256 timestamp)",
        "function mode() external view returns (uint8)",
        "function emergencyMode() external view returns (bool)",
        "function priceInitialized() external view returns (bool)",
        "function readChannel() external view returns (uint32)",
        "function latestPrice() external view returns (int256)",
        "function lastUpdateTime() external view returns (uint256)"
    ];
    
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, arbitrumProvider);
    
    try {
        console.log("=== 📊 Arbitrum Oracle State ===");
        
        const mode = await oracle.mode();
        const emergencyMode = await oracle.emergencyMode();
        const priceInitialized = await oracle.priceInitialized();
        const readChannel = await oracle.readChannel();
        
        console.log(`Mode: ${mode} (0=UNINITIALIZED, 1=PRIMARY, 2=SECONDARY)`);
        console.log(`Emergency Mode: ${emergencyMode}`);
        console.log(`Price Initialized: ${priceInitialized}`);
        console.log(`Read Channel: ${readChannel}`);
        
        // Try to call getLatestPrice directly
        console.log("\n=== 📈 Direct getLatestPrice() Call ===");
        try {
            const latestPrice = await oracle.getLatestPrice();
            console.log(`✅ getLatestPrice() succeeded:`);
            console.log(`   Price: ${latestPrice.price.toString()}`);
            console.log(`   Timestamp: ${latestPrice.timestamp.toString()}`);
            
            if (latestPrice.timestamp.gt(0)) {
                const date = new Date(latestPrice.timestamp.toNumber() * 1000);
                console.log(`   Date: ${date.toISOString()}`);
                
                const now = Math.floor(Date.now() / 1000);
                const age = now - latestPrice.timestamp.toNumber();
                console.log(`   Age: ${age} seconds (${Math.floor(age / 60)} minutes)`);
            }
            
            if (latestPrice.price.eq(0) || latestPrice.timestamp.eq(0)) {
                console.log("⚠️  WARNING: getLatestPrice() returns zero values");
                console.log("   This will cause LayerZero Read to return empty data");
            }
            
        } catch (error) {
            console.log(`❌ getLatestPrice() failed: ${error.message}`);
            console.log(`   This is likely why LayerZero Read is failing!`);
            
            // Try individual state calls
            console.log("\n=== 🧪 Individual State Checks ===");
            try {
                const latestPrice = await oracle.latestPrice();
                const lastUpdateTime = await oracle.lastUpdateTime();
                console.log(`   Latest Price: ${latestPrice.toString()}`);
                console.log(`   Last Update Time: ${lastUpdateTime.toString()}`);
            } catch (e) {
                console.log(`   Error reading state: ${e.message}`);
            }
        }
        
        // Check if oracle is in correct mode
        console.log("\n=== ⚡ Configuration Issues ===");
        if (mode === 0) {
            console.log("❌ CRITICAL: Oracle mode is UNINITIALIZED");
            console.log("   Fix: Call setMode(1) for PRIMARY or setMode(2) for SECONDARY");
        }
        if (emergencyMode) {
            console.log("❌ CRITICAL: Oracle is in emergency mode");
            console.log("   Fix: Call toggleEmergencyMode()");
        }
        if (!priceInitialized) {
            console.log("⚠️  WARNING: Price not initialized");
            if (mode === 1) {
                console.log("   Fix: Call updatePrice() if in PRIMARY mode");
            }
        }
        
        // Check network connectivity
        console.log("\n=== 🌐 Network Info ===");
        const network = await arbitrumProvider.getNetwork();
        const blockNumber = await arbitrumProvider.getBlockNumber();
        console.log(`   Network: ${network.name} (chainId: ${network.chainId})`);
        console.log(`   Latest Block: ${blockNumber}`);
        
    } catch (error) {
        console.error("❌ Error debugging Arbitrum oracle:");
        console.error(error.message);
        
        if (error.code === 'NETWORK_ERROR' || error.message.includes('network')) {
            console.error("\n🔧 NETWORK ISSUE:");
            console.error("   - Check if RPC_URL_ARBITRUM is set correctly in .env");
            console.error("   - Verify the Arbitrum RPC endpoint is working");
            console.error("   - The oracle contract may not be deployed at the expected address");
        }
    }
}

debugArbitrumOracle().catch(console.error);
