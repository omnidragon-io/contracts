const { ethers } = require('hardhat');

async function updateArbitrumPrice() {
    console.log("📊 Updating Arbitrum Oracle price...\n");

    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    const oracle = await ethers.getContractAt("OmniDragonOracle", oracleAddress);
    
    try {
        console.log("🚀 Calling updatePrice()...");
        const tx = await oracle.updatePrice({
            gasLimit: 500000
        });
        
        console.log(`Transaction: ${tx.hash}`);
        const receipt = await tx.wait();
        console.log(`✅ Confirmed in block ${receipt.blockNumber}`);
        
        // Check for events
        receipt.events?.forEach((event) => {
            if (event.event === 'PriceUpdated') {
                console.log(`\n📈 PriceUpdated Event:`);
                console.log(`   Dragon Price: ${event.args.dragonPrice.toString()}`);
                console.log(`   Native Price: ${event.args.nativePrice.toString()}`);  
                console.log(`   Timestamp: ${event.args.timestamp.toString()}`);
            }
        });
        
        // Verify the update
        const latestPrice = await oracle.getLatestPrice();
        console.log(`\n🔍 Verification:`);
        console.log(`   Price: ${latestPrice.price.toString()}`);
        console.log(`   Timestamp: ${latestPrice.timestamp.toString()}`);
        
        if (latestPrice.timestamp.gt(0)) {
            const date = new Date(latestPrice.timestamp.toNumber() * 1000);
            console.log(`   Date: ${date.toISOString()}`);
            console.log("\n🎉 SUCCESS! Oracle price is now initialized!");
        } else {
            console.log("\n❌ Price still not initialized");
        }
        
    } catch (error) {
        console.error("❌ Error:", error.message);
        if (error.reason) console.error("Reason:", error.reason);
    }
}

updateArbitrumPrice().catch(console.error);
