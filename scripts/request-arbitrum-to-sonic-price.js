const { ethers } = require('hardhat');
const { EndpointId } = require('@layerzerolabs/lz-definitions');

// Contract addresses from config
const ARBITRUM_ORACLE = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
const SONIC_ORACLE = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";

// Endpoint IDs
const ARBITRUM_EID = 30110;  // EndpointId.ARBITRUM_V2_MAINNET
const SONIC_EID = 30332;     // EndpointId.SONIC_V2_MAINNET

async function requestPriceFromArbitrumToSonic() {
    console.log("🐉 Requesting cross-chain price from Arbitrum to Sonic...\n");

    // Connect to Sonic network (where we'll initiate the request)
    const sonicProvider = new ethers.providers.JsonRpcProvider(process.env.SONIC_RPC_URL);
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY, sonicProvider);
    
    console.log(`🔗 Connected to Sonic network`);
    console.log(`📄 Sonic Oracle: ${SONIC_ORACLE}`);
    console.log(`🎯 Target: Request price from Arbitrum (EID: ${ARBITRUM_EID})`);
    console.log(`💳 From wallet: ${signer.address}\n`);

    // Get the Oracle contract ABI
    const oracleArtifact = require('../deployments/sonic/OmniDragonOracle.json');
    const oracleContract = new ethers.Contract(SONIC_ORACLE, oracleArtifact.abi, signer);

    try {
        // Step 1: Check if Arbitrum peer is active
        console.log("🔍 Step 1: Checking Arbitrum peer configuration...");
        const peerOracle = await oracleContract.peerOracles(ARBITRUM_EID);
        const isPeerActive = await oracleContract.activePeers(ARBITRUM_EID);
        
        console.log(`   Arbitrum Oracle Peer: ${peerOracle}`);
        console.log(`   Is Peer Active: ${isPeerActive}\n`);

        if (!isPeerActive || peerOracle === ethers.constants.AddressZero) {
            throw new Error("Arbitrum peer is not configured or inactive");
        }

        // Step 2: Quote the fee for the LayerZero cross-chain request
        console.log("💰 Step 2: Quoting LayerZero fee...");
        const extraOptions = "0x"; // Empty extra options for default settings
        const fee = await oracleContract.quoteFee(ARBITRUM_EID, extraOptions);
        
        console.log(`   Native Fee: ${ethers.utils.formatEther(fee.nativeFee)} S`);
        console.log(`   LZ Token Fee: ${fee.lzTokenFee}\n`);

        // Step 3: Check wallet balance
        const balance = await signer.getBalance();
        console.log(`💼 Current wallet balance: ${ethers.utils.formatEther(balance)} S`);
        
        if (balance.lt(fee.nativeFee)) {
            throw new Error(`Insufficient balance. Need ${ethers.utils.formatEther(fee.nativeFee)} S`);
        }

        // Step 4: Execute the cross-chain price request
        console.log("🚀 Step 3: Sending cross-chain price request...");
        
        const tx = await oracleContract.requestPrice(ARBITRUM_EID, extraOptions, {
            value: fee.nativeFee,
            gasLimit: 300000 // Set reasonable gas limit
        });
        
        console.log(`   Transaction hash: ${tx.hash}`);
        console.log(`   Waiting for confirmation...\n`);
        
        const receipt = await tx.wait();
        console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);

        // Look for the PriceRequested event
        const priceRequestedEvent = receipt.events.find(e => e.event === 'PriceRequested');
        if (priceRequestedEvent) {
            console.log(`📡 Price request sent with GUID: ${priceRequestedEvent.args.guid}`);
            console.log(`   Target EID: ${priceRequestedEvent.args.targetEid}`);
            console.log(`   Fee Paid: ${ethers.utils.formatEther(priceRequestedEvent.args.fee)} S`);
        }

        console.log("\n🎉 Cross-chain price request sent successfully!");
        console.log("⏳ The price data should be received shortly via LayerZero...");
        console.log("🔍 You can monitor the CrossChainPriceReceived event for the response.\n");

        // Step 5: Show how to check for received price data
        console.log("📊 To check if price data was received, run:");
        console.log(`   await oracleContract.getPrice(${ARBITRUM_EID})`);
        console.log("\nOr monitor events:");
        console.log("   CrossChainPriceReceived(uint32 indexed targetEid, int256 dragonPrice, int256 nativePrice, uint256 timestamp)");

    } catch (error) {
        console.error("❌ Error requesting cross-chain price:");
        console.error(error.message);
        if (error.reason) console.error("Reason:", error.reason);
    }
}

// Execute if called directly
if (require.main === module) {
    requestPriceFromArbitrumToSonic()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { requestPriceFromArbitrumToSonic };
