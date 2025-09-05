const { ethers } = require('hardhat');

// Contract addresses and endpoint IDs
const ARBITRUM_ORACLE = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
const SONIC_ORACLE = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
const ARBITRUM_EID = 30110;
const SONIC_EID = 30332;

async function diagnoseOracle() {
    console.log("🔍 Diagnosing OmniDragonOracle configuration...\n");

    // Connect to Sonic network
    const sonicProvider = new ethers.providers.JsonRpcProvider(process.env.SONIC_RPC_URL);
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY, sonicProvider);
    
    console.log(`🔗 Connected to Sonic network`);
    console.log(`📄 Sonic Oracle: ${SONIC_ORACLE}`);
    console.log(`💳 Wallet: ${signer.address}\n`);

    // Get the Oracle contract
    const oracleArtifact = require('../deployments/sonic/OmniDragonOracle.json');
    const oracleContract = new ethers.Contract(SONIC_ORACLE, oracleArtifact.abi, signer);

    try {
        // Check basic oracle state
        console.log("=== 📊 Basic Oracle State ===");
        const mode = await oracleContract.mode();
        const emergencyMode = await oracleContract.emergencyMode();
        const readChannel = await oracleContract.readChannel();
        const priceInitialized = await oracleContract.priceInitialized();
        
        console.log(`Mode: ${mode} (0=UNINITIALIZED, 1=PRIMARY, 2=SECONDARY)`);
        console.log(`Emergency Mode: ${emergencyMode}`);
        console.log(`Read Channel: ${readChannel}`);
        console.log(`Price Initialized: ${priceInitialized}\n`);

        // Check peer configuration
        console.log("=== 🔗 Peer Configuration ===");
        const peerOracle = await oracleContract.peerOracles(ARBITRUM_EID);
        const isPeerActive = await oracleContract.activePeers(ARBITRUM_EID);
        const activePeerEids = await oracleContract.activePeerEids(0).catch(() => "Error reading array");
        
        console.log(`Arbitrum Peer Oracle: ${peerOracle}`);
        console.log(`Is Arbitrum Peer Active: ${isPeerActive}`);
        console.log(`Active Peer EIDs (first): ${activePeerEids}\n`);

        // Check LayerZero peer configuration  
        console.log("=== 🌐 LayerZero Peer Configuration ===");
        try {
            const lzPeer = await oracleContract.peers(ARBITRUM_EID);
            console.log(`LayerZero Peer (bytes32): ${lzPeer}`);
            
            const peerAddress = await oracleContract.getPeer(ARBITRUM_EID);
            console.log(`LayerZero Peer (address): ${peerAddress}`);
        } catch (error) {
            console.log(`❌ Error reading LayerZero peer: ${error.message}`);
        }

        // Check read channel configuration
        console.log("\n=== 📡 Read Channel Configuration ===");
        try {
            const readChannelPeer = await oracleContract.peers(readChannel);
            console.log(`Read Channel Peer: ${readChannelPeer}`);
        } catch (error) {
            console.log(`❌ Error reading channel peer: ${error.message}`);
        }

        // Try to quote fee to see if that works
        console.log("\n=== 💰 Fee Quote Test ===");
        try {
            const extraOptions = "0x";
            const fee = await oracleContract.quoteFee(ARBITRUM_EID, extraOptions);
            console.log(`✅ Fee quote successful:`);
            console.log(`   Native Fee: ${ethers.utils.formatEther(fee.nativeFee)} S`);
            console.log(`   LZ Token Fee: ${fee.lzTokenFee}`);
        } catch (error) {
            console.log(`❌ Fee quote failed: ${error.message}`);
            if (error.reason) console.log(`   Reason: ${error.reason}`);
        }

        // Check current price data
        console.log("\n=== 📈 Current Price Data ===");
        try {
            const latestPrice = await oracleContract.getLatestPrice();
            console.log(`Latest Price: ${latestPrice.price} (timestamp: ${latestPrice.timestamp})`);
        } catch (error) {
            console.log(`❌ Error getting latest price: ${error.message}`);
        }

        // Check validation status
        console.log("\n=== ✅ Validation Status ===");
        try {
            const validation = await oracleContract.validate();
            console.log(`Local Valid: ${validation.localValid}`);
            console.log(`Cross-chain Valid: ${validation.crossChainValid}`);
        } catch (error) {
            console.log(`❌ Error validating: ${error.message}`);
        }

        // Test the specific function call that's failing
        console.log("\n=== 🧪 Direct Function Test ===");
        try {
            console.log("Testing requestPrice parameters...");
            console.log(`Target EID: ${ARBITRUM_EID}`);
            console.log(`Extra Options: 0x`);
            
            // Try to simulate the call
            await oracleContract.callStatic.requestPrice(ARBITRUM_EID, "0x", {
                value: ethers.utils.parseEther("0.5") // Use a reasonable amount
            });
            console.log("✅ Static call succeeded - transaction should work");
            
        } catch (error) {
            console.log(`❌ Static call failed: ${error.message}`);
            if (error.reason) console.log(`   Reason: ${error.reason}`);
            
            // Try to get more specific error info
            try {
                const errorData = error.error?.data || error.data;
                if (errorData) {
                    console.log(`   Error data: ${errorData}`);
                }
            } catch (e) {}
        }

        console.log("\n=== 🔧 Recommendations ===");
        if (readChannel === 0) {
            console.log("❌ Read channel is not set. Run: oracle.setReadChannel(4294967295, true)");
        }
        if (!isPeerActive) {
            console.log("❌ Arbitrum peer is not active. Run: oracle.setPeer(30110, '0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777')");
        }
        if (mode === 0) {
            console.log("❌ Oracle mode is UNINITIALIZED. Run: oracle.setMode(2) for SECONDARY mode");
        }
        if (emergencyMode) {
            console.log("❌ Oracle is in emergency mode. Run: oracle.toggleEmergencyMode()");
        }

    } catch (error) {
        console.error("❌ Error during diagnosis:");
        console.error(error.message);
    }
}

// Execute if called directly
if (require.main === module) {
    diagnoseOracle()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { diagnoseOracle };
