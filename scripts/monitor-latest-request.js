const { ethers } = require("ethers");
require('dotenv').config();

async function monitorLatestRequest() {
    console.log("👀 Monitoring latest LayerZero cross-chain request...\n");

    const provider = new ethers.providers.JsonRpcProvider(process.env.SONIC_RPC_URL);
    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    const arbitrumEid = 30110;
    const latestGuid = "0x67039bf8866a3025900c3074980710ba68340f170dad3491b5223caf298cf9b0";
    
    console.log(`📊 Latest GUID: ${latestGuid}`);
    console.log(`🎯 Target EID: ${arbitrumEid}`);
    console.log(`🕒 Monitoring for 2 minutes...\n`);

    const oracleAbi = [
        "function getPrice(uint32 _eid) external view returns (int256 dragonPrice, int256 nativePrice, uint256 timestamp, bool isValid)",
        "event CrossChainPriceReceived(uint32 indexed targetEid, int256 dragonPrice, int256 nativePrice, uint256 timestamp)"
    ];
    
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, provider);
    
    // Monitor for 2 minutes
    let received = false;
    const startTime = Date.now();
    const timeout = 120000; // 2 minutes
    
    const checkInterval = setInterval(async () => {
        try {
            const elapsed = Date.now() - startTime;
            console.log(`⏰ Checking... (${Math.floor(elapsed / 1000)}s elapsed)`);
            
            // Check current price data
            const priceData = await oracle.getPrice(arbitrumEid);
            console.log(`   Price: ${priceData.dragonPrice.toString()}`);
            console.log(`   Timestamp: ${priceData.timestamp.toString()}`);
            console.log(`   Valid: ${priceData.isValid}`);
            
            if (priceData.timestamp.gt(0)) {
                console.log("\n🎊 SUCCESS! Cross-chain price data received!");
                console.log(`   Dragon Price: ${priceData.dragonPrice.toString()}`);
                console.log(`   Native Price: ${priceData.nativePrice.toString()}`);
                console.log(`   Timestamp: ${priceData.timestamp.toString()}`);
                
                const date = new Date(priceData.timestamp.toNumber() * 1000);
                console.log(`   Date: ${date.toISOString()}`);
                
                received = true;
                clearInterval(checkInterval);
                return;
            }
            
            if (elapsed > timeout) {
                console.log("\n⏰ Timeout reached - LayerZero message may still be processing");
                console.log("🔍 Check LayerZero scan for message status:");
                console.log(`   https://layerzeroscan.com/tx/${latestGuid}`);
                clearInterval(checkInterval);
                return;
            }
            
        } catch (error) {
            console.log(`   Error checking: ${error.message}`);
        }
    }, 10000); // Check every 10 seconds
    
    // Also listen for events
    console.log("📡 Listening for CrossChainPriceReceived events...\n");
    
    oracle.on('CrossChainPriceReceived', (targetEid, dragonPrice, nativePrice, timestamp, event) => {
        if (targetEid === arbitrumEid && !received) {
            console.log("\n🎉 RECEIVED CrossChainPriceReceived EVENT!");
            console.log(`   Target EID: ${targetEid}`);
            console.log(`   Dragon Price: ${dragonPrice.toString()}`);
            console.log(`   Native Price: ${nativePrice.toString()}`);
            console.log(`   Timestamp: ${timestamp.toString()}`);
            console.log(`   Block: ${event.blockNumber}`);
            console.log(`   Transaction: ${event.transactionHash}`);
            
            received = true;
            clearInterval(checkInterval);
            oracle.removeAllListeners();
        }
    });
}

monitorLatestRequest().catch(console.error);
