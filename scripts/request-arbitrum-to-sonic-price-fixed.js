const { ethers } = require('hardhat');

// Contract addresses and endpoint IDs
const ARBITRUM_ORACLE = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
const SONIC_ORACLE = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
const ARBITRUM_EID = 30110;
const SONIC_EID = 30332;

async function requestPriceFromArbitrumToSonicFixed() {
    console.log("🐉 Requesting cross-chain price from Arbitrum to Sonic (Fixed Version)...\n");

    // Connect to Sonic network with retry logic
    const sonicProvider = new ethers.providers.JsonRpcProvider(process.env.SONIC_RPC_URL);
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY, sonicProvider);
    
    console.log(`🔗 Connected to Sonic network`);
    console.log(`📄 Sonic Oracle: ${SONIC_ORACLE}`);
    console.log(`🎯 Target: Request price from Arbitrum (EID: ${ARBITRUM_EID})`);
    console.log(`💳 From wallet: ${signer.address}\n`);

    // Get the Oracle contract
    const oracleArtifact = require('../deployments/sonic/OmniDragonOracle.json');
    const oracleContract = new ethers.Contract(SONIC_ORACLE, oracleArtifact.abi, signer);

    try {
        // Step 1: Verify configuration
        console.log("🔍 Step 1: Verifying configuration...");
        const isPeerActive = await oracleContract.activePeers(ARBITRUM_EID);
        const readChannel = await oracleContract.readChannel();
        const mode = await oracleContract.mode();
        
        console.log(`   Arbitrum Peer Active: ${isPeerActive}`);
        console.log(`   Read Channel: ${readChannel}`);
        console.log(`   Oracle Mode: ${mode} (1=PRIMARY, 2=SECONDARY)\n`);

        if (!isPeerActive) throw new Error("Arbitrum peer is not active");
        if (readChannel === 0) throw new Error("Read channel is not configured");

        // Step 2: Quote fee with buffer
        console.log("💰 Step 2: Quoting LayerZero fee...");
        const extraOptions = "0x"; 
        const fee = await oracleContract.quoteFee(ARBITRUM_EID, extraOptions);
        
        // Add 20% buffer to the fee
        const feeWithBuffer = fee.nativeFee.mul(120).div(100);
        
        console.log(`   Quoted Fee: ${ethers.utils.formatEther(fee.nativeFee)} S`);
        console.log(`   Fee with buffer: ${ethers.utils.formatEther(feeWithBuffer)} S\n`);

        // Step 3: Check wallet balance
        const balance = await signer.getBalance();
        console.log(`💼 Current wallet balance: ${ethers.utils.formatEther(balance)} S`);
        
        if (balance.lt(feeWithBuffer)) {
            throw new Error(`Insufficient balance. Need ${ethers.utils.formatEther(feeWithBuffer)} S`);
        }

        // Step 4: Get current gas price and set proper gas parameters
        console.log("\n⛽ Step 3: Setting gas parameters...");
        const feeData = await sonicProvider.getFeeData();
        console.log(`   Current gas price: ${ethers.utils.formatUnits(feeData.gasPrice || 0, 'gwei')} gwei`);
        console.log(`   Max fee per gas: ${ethers.utils.formatUnits(feeData.maxFeePerGas || 0, 'gwei')} gwei`);
        
        // Use higher gas limit and add buffer to gas price
        const gasLimit = 500000; // Increased gas limit
        const maxFeePerGas = feeData.maxFeePerGas ? feeData.maxFeePerGas.mul(150).div(100) : ethers.utils.parseUnits('100', 'gwei');
        const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas ? feeData.maxPriorityFeePerGas.mul(150).div(100) : ethers.utils.parseUnits('2', 'gwei');

        // Step 5: Execute with better parameters
        console.log("\n🚀 Step 4: Sending cross-chain price request...");
        
        const txParams = {
            value: feeWithBuffer,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas
        };
        
        console.log(`   Using gas limit: ${gasLimit}`);
        console.log(`   Using max fee per gas: ${ethers.utils.formatUnits(maxFeePerGas, 'gwei')} gwei`);
        console.log(`   Sending with fee: ${ethers.utils.formatEther(feeWithBuffer)} S`);
        
        const tx = await oracleContract.requestPrice(ARBITRUM_EID, extraOptions, txParams);
        
        console.log(`   Transaction hash: ${tx.hash}`);
        console.log(`   Waiting for confirmation...\n`);
        
        const receipt = await tx.wait();
        
        if (receipt.status === 1) {
            console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
            console.log(`⛽ Gas used: ${receipt.gasUsed.toString()} / ${gasLimit}`);
            
            // Look for events
            const priceRequestedEvent = receipt.events?.find(e => e.event === 'PriceRequested');
            if (priceRequestedEvent) {
                const args = priceRequestedEvent.args;
                console.log(`📡 Price request sent with GUID: ${args.guid}`);
                console.log(`   Target EID: ${args.targetEid}`);
                console.log(`   Sender: ${args.sender}`);
                console.log(`   Fee Paid: ${ethers.utils.formatEther(args.fee)} S`);
            }

            console.log("\n🎉 Cross-chain price request sent successfully!");
            console.log("⏳ The price data should be received shortly via LayerZero...");
            
            // Step 6: Monitor for response (optional)
            console.log("\n👀 Monitoring for CrossChainPriceReceived event (30 seconds)...");
            
            const responsePromise = new Promise((resolve, reject) => {
                const timeout = setTimeout(() => {
                    oracleContract.removeAllListeners('CrossChainPriceReceived');
                    resolve(null);
                }, 30000); // 30 second timeout

                oracleContract.once('CrossChainPriceReceived', (targetEid, dragonPrice, nativePrice, timestamp, event) => {
                    clearTimeout(timeout);
                    resolve({ targetEid, dragonPrice, nativePrice, timestamp, event });
                });
            });

            const response = await responsePromise;
            if (response) {
                console.log("🎊 Received cross-chain price data!");
                console.log(`   Target EID: ${response.targetEid}`);
                console.log(`   Dragon Price: ${response.dragonPrice.toString()}`);
                console.log(`   Native Price: ${response.nativePrice.toString()}`);
                console.log(`   Timestamp: ${response.timestamp}`);
                console.log(`   Block: ${response.event.blockNumber}`);
            } else {
                console.log("⏰ Timeout waiting for response. Check later with:");
                console.log(`   await oracleContract.getPrice(${ARBITRUM_EID})`);
            }

        } else {
            throw new Error("Transaction failed");
        }

    } catch (error) {
        console.error("❌ Error requesting cross-chain price:");
        console.error(error.message);
        if (error.reason) console.error("Reason:", error.reason);
        if (error.code) console.error("Code:", error.code);
        
        // Additional debugging
        if (error.transaction) {
            console.error("Transaction that failed:");
            console.error(`  Hash: ${error.transaction.hash}`);
            console.error(`  Gas Limit: ${error.transaction.gasLimit}`);
            console.error(`  Gas Price: ${error.transaction.gasPrice || error.transaction.maxFeePerGas}`);
            console.error(`  Value: ${ethers.utils.formatEther(error.transaction.value)} S`);
        }
    }
}

// Execute if called directly
if (require.main === module) {
    requestPriceFromArbitrumToSonicFixed()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

module.exports = { requestPriceFromArbitrumToSonicFixed };
