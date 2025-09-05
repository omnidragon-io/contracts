const { ethers } = require("ethers");
require('dotenv').config();

async function checkReceivedPrice() {
    console.log("👀 Checking for received cross-chain price data...\n");

    const provider = new ethers.providers.JsonRpcProvider(process.env.SONIC_RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    const arbitrumEid = 30110;
    
    const oracleAbi = [
        "function getPrice(uint32 _eid) external view returns (int256 dragonPrice, int256 nativePrice, uint256 timestamp, bool isValid)",
        "function peerDragonPrices(uint32) external view returns (int256)",
        "function peerNativePrices(uint32) external view returns (int256)",
        "function peerPriceTimestamps(uint32) external view returns (uint256)",
        "event CrossChainPriceReceived(uint32 indexed targetEid, int256 dragonPrice, int256 nativePrice, uint256 timestamp)"
    ];
    
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, wallet);
    
    try {
        console.log(`📊 Checking price data from Arbitrum (EID: ${arbitrumEid})...\n`);
        
        // Get current price data
        const priceData = await oracle.getPrice(arbitrumEid);
        console.log("=== 📈 Current Price Data ===");
        console.log(`Dragon Price: ${priceData.dragonPrice.toString()}`);
        console.log(`Native Price: ${priceData.nativePrice.toString()}`);
        console.log(`Timestamp: ${priceData.timestamp.toString()}`);
        console.log(`Is Valid: ${priceData.isValid}`);
        
        if (priceData.timestamp.gt(0)) {
            const date = new Date(priceData.timestamp.toNumber() * 1000);
            console.log(`Date: ${date.toISOString()}`);
            
            const now = Math.floor(Date.now() / 1000);
            const age = now - priceData.timestamp.toNumber();
            console.log(`Age: ${age} seconds (${Math.floor(age / 60)} minutes)\n`);
        } else {
            console.log("❌ No price data received yet\n");
        }
        
        // Check individual mappings
        console.log("=== 🔍 Direct Mapping Values ===");
        const dragonPrice = await oracle.peerDragonPrices(arbitrumEid);
        const nativePrice = await oracle.peerNativePrices(arbitrumEid);
        const timestamp = await oracle.peerPriceTimestamps(arbitrumEid);
        
        console.log(`Peer Dragon Price: ${dragonPrice.toString()}`);
        console.log(`Peer Native Price: ${nativePrice.toString()}`);
        console.log(`Peer Timestamp: ${timestamp.toString()}\n`);
        
        // Look for recent CrossChainPriceReceived events
        console.log("=== 📡 Recent Events ===");
        const currentBlock = await provider.getBlockNumber();
        const fromBlock = Math.max(0, currentBlock - 1000); // Last ~1000 blocks
        
        console.log(`Searching blocks ${fromBlock} to ${currentBlock}...`);
        
        const filter = oracle.filters.CrossChainPriceReceived(arbitrumEid);
        const events = await oracle.queryFilter(filter, fromBlock, currentBlock);
        
        if (events.length > 0) {
            console.log(`\n✅ Found ${events.length} CrossChainPriceReceived event(s):`);
            events.forEach((event, index) => {
                console.log(`\n   Event ${index + 1}:`);
                console.log(`   Block: ${event.blockNumber}`);
                console.log(`   Transaction: ${event.transactionHash}`);
                console.log(`   Target EID: ${event.args.targetEid}`);
                console.log(`   Dragon Price: ${event.args.dragonPrice.toString()}`);
                console.log(`   Native Price: ${event.args.nativePrice.toString()}`);
                console.log(`   Timestamp: ${event.args.timestamp.toString()}`);
                
                const eventDate = new Date(event.args.timestamp.toNumber() * 1000);
                console.log(`   Date: ${eventDate.toISOString()}`);
            });
        } else {
            console.log("❌ No CrossChainPriceReceived events found in recent blocks");
            console.log("⏳ Price data may still be in transit via LayerZero...");
        }
        
        // Summary
        console.log("\n=== 📋 Summary ===");
        if (priceData.isValid) {
            console.log("✅ Valid cross-chain price data is available!");
            console.log(`   Dragon Price: ${priceData.dragonPrice.toString()}`);
            console.log(`   Native Price: ${priceData.nativePrice.toString()}`);
        } else if (priceData.timestamp.gt(0)) {
            console.log("⚠️  Price data exists but is not considered valid (likely stale)");
        } else {
            console.log("❌ No cross-chain price data received yet");
            console.log("💡 LayerZero messages can take several minutes to process");
            console.log("   Try running this script again in a few minutes");
        }
        
    } catch (error) {
        console.error("\n❌ Error checking price:", error.message);
        if (error.reason) console.error("Reason:", error.reason);
    }
}

checkReceivedPrice().catch(console.error);
