const { ethers } = require("ethers");
require('dotenv').config();

async function checkArbitrumEvents() {
    console.log("🔍 Checking Arbitrum oracle for received price events...\n");

    const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL_ARBITRUM);
    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    const sonicEid = 30332;
    
    const oracleAbi = [
        "function peerDragonPrices(uint32) external view returns (int256)",
        "function peerNativePrices(uint32) external view returns (int256)", 
        "function peerPriceTimestamps(uint32) external view returns (uint256)",
        "function getPrice(uint32 _eid) external view returns (int256 dragonPrice, int256 nativePrice, uint256 timestamp, bool isValid)",
        "event CrossChainPriceReceived(uint32 indexed targetEid, int256 dragonPrice, int256 nativePrice, uint256 timestamp)"
    ];
    
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, provider);
    
    try {
        console.log(`📊 Checking price data from Sonic (EID: ${sonicEid})...\n`);
        
        // Check current price data
        const priceData = await oracle.getPrice(sonicEid);
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
        const dragonPrice = await oracle.peerDragonPrices(sonicEid);
        const nativePrice = await oracle.peerNativePrices(sonicEid);
        const timestamp = await oracle.peerPriceTimestamps(sonicEid);
        
        console.log(`Peer Dragon Price: ${dragonPrice.toString()}`);
        console.log(`Peer Native Price: ${nativePrice.toString()}`);
        console.log(`Peer Timestamp: ${timestamp.toString()}\n`);
        
        // Look for recent CrossChainPriceReceived events
        console.log("=== 📡 Recent Events ===");
        const currentBlock = await provider.getBlockNumber();
        const fromBlock = Math.max(0, currentBlock - 2000); // Last ~2000 blocks
        
        console.log(`Searching blocks ${fromBlock} to ${currentBlock}...`);
        
        try {
            const filter = oracle.filters.CrossChainPriceReceived(sonicEid);
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
                    
                    if (event.args.timestamp.gt(0)) {
                        const eventDate = new Date(event.args.timestamp.toNumber() * 1000);
                        console.log(`   Date: ${eventDate.toISOString()}`);
                    }
                });
            } else {
                console.log("❌ No CrossChainPriceReceived events found");
            }
        } catch (eventError) {
            console.log(`❌ Error querying events: ${eventError.message}`);
        }
        
        // Summary and next steps
        console.log("\n=== 📋 Summary ===");
        if (priceData.timestamp.gt(0)) {
            console.log("🎉 SUCCESS! Arbitrum has received price data from Sonic!");
            console.log("✅ The oracle is now initialized and can respond to LayerZero Read");
            console.log("🔄 You can now retry the original Arbitrum→Sonic price request");
            return true;
        } else {
            console.log("⏳ LayerZero message still processing or failed");
            console.log("💡 Check LayerZero scan:");
            console.log("   https://layerzeroscan.com/tx/0xee8d73e574a57a9e453cc1530e776bf0aa0a58ced4204d394c31a9ecf85affb9");
            console.log("\n🔄 If processing, wait a few more minutes and run again");
            return false;
        }
        
    } catch (error) {
        console.error("\n❌ Error checking Arbitrum events:");
        console.error(error.message);
        return false;
    }
}

checkArbitrumEvents().catch(console.error);
