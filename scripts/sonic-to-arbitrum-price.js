const { ethers } = require("ethers");
require('dotenv').config();

async function sendPriceFromSonicToArbitrum() {
    console.log("📤 Sending price data from Sonic (PRIMARY) to Arbitrum (SECONDARY)...\n");

    const provider = new ethers.providers.JsonRpcProvider(process.env.SONIC_RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    const arbitrumEid = 30110;
    
    console.log(`🔗 Connected to Sonic network`);
    console.log(`📄 Sonic Oracle: ${oracleAddress}`);
    console.log(`🎯 Target: Send price to Arbitrum (EID: ${arbitrumEid})`);
    console.log(`💳 From wallet: ${wallet.address}\n`);

    const oracleAbi = [
        "function requestPrice(uint32 _targetEid, bytes calldata _extraOptions) external payable returns (tuple(bytes32 guid, uint64 nonce, tuple(uint256 nativeFee, uint256 lzTokenFee) fee))",
        "function quoteFee(uint32 _targetEid, bytes calldata _extraOptions) external view returns (tuple(uint256 nativeFee, uint256 lzTokenFee))",
        "function activePeers(uint32) external view returns (bool)",
        "function getLatestPrice() external view returns (int256 price, uint256 timestamp)",
        "function mode() external view returns (uint8)",
        "function priceInitialized() external view returns (bool)",
        "event PriceRequested(bytes32 indexed guid, uint32 indexed targetEid, address indexed sender, uint256 fee)"
    ];
    
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, wallet);
    
    try {
        // Verify Sonic is ready to send
        console.log("🔍 Verifying Sonic oracle state...");
        const mode = await oracle.mode();
        const priceInitialized = await oracle.priceInitialized();
        const currentPrice = await oracle.getLatestPrice();
        const isPeerActive = await oracle.activePeers(arbitrumEid);
        
        console.log(`   Mode: ${mode} (1=PRIMARY)`);
        console.log(`   Price Initialized: ${priceInitialized}`);
        console.log(`   Current Price: ${currentPrice.price.toString()}`);
        console.log(`   Current Timestamp: ${currentPrice.timestamp.toString()}`);
        console.log(`   Arbitrum Peer Active: ${isPeerActive}\n`);
        
        if (mode !== 1) throw new Error("Sonic oracle must be in PRIMARY mode");
        if (!priceInitialized) throw new Error("Sonic oracle must be initialized");
        if (!isPeerActive) throw new Error("Arbitrum peer not configured");
        if (currentPrice.timestamp.eq(0)) throw new Error("Sonic oracle has no valid price data");
        
        // Quote fee
        console.log("💰 Quoting LayerZero fee...");
        const extraOptions = "0x";
        const fee = await oracle.quoteFee(arbitrumEid, extraOptions);
        
        console.log(`   Native Fee: ${ethers.utils.formatEther(fee.nativeFee)} S`);
        console.log(`   LZ Token Fee: ${fee.lzTokenFee}\n`);
        
        // Check balance
        const balance = await wallet.getBalance();
        console.log(`💼 Current wallet balance: ${ethers.utils.formatEther(balance)} S`);
        
        if (balance.lt(fee.nativeFee)) {
            throw new Error(`Insufficient balance. Need ${ethers.utils.formatEther(fee.nativeFee)} S`);
        }
        
        // Send price data to initialize Arbitrum oracle
        console.log("🚀 Sending price data to initialize Arbitrum oracle...");
        
        const tx = await oracle.requestPrice(arbitrumEid, extraOptions, {
            value: fee.nativeFee,
            gasLimit: 400000
        });
        
        console.log(`   Transaction: ${tx.hash}`);
        console.log("   Waiting for confirmation...");
        
        const receipt = await tx.wait();
        console.log(`✅ Confirmed in block ${receipt.blockNumber}`);
        console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
        
        // Parse events
        receipt.logs.forEach((log) => {
            try {
                const parsed = oracle.interface.parseLog(log);
                if (parsed.name === 'PriceRequested') {
                    console.log(`\n📡 PriceRequested Event:`);
                    console.log(`   GUID: ${parsed.args.guid}`);
                    console.log(`   Target EID: ${parsed.args.targetEid}`);
                    console.log(`   Sender: ${parsed.args.sender}`);
                    console.log(`   Fee: ${ethers.utils.formatEther(parsed.args.fee)} S`);
                }
            } catch (e) {
                // Not our event
            }
        });
        
        console.log("\n🎉 Price initialization request sent to Arbitrum!");
        console.log("📊 This will:");
        console.log("   1. Send Sonic's current price data to Arbitrum");
        console.log("   2. Initialize the Arbitrum oracle (priceInitialized = true)");
        console.log("   3. Enable Arbitrum to respond to LayerZero Read requests");
        console.log("   4. Fix our original cross-chain price request issue!");
        
        console.log("\n⏳ Wait ~2-5 minutes for LayerZero processing, then:");
        console.log("   1. Check if Arbitrum oracle is now initialized");
        console.log("   2. Retry our original Arbitrum→Sonic price request");
        console.log("   3. It should now work without the timestamp revert!");
        
        return true;
        
    } catch (error) {
        console.error("\n❌ Error sending price data:");
        console.error(error.message);
        if (error.reason) console.error("Reason:", error.reason);
        return false;
    }
}

sendPriceFromSonicToArbitrum().catch(console.error);
