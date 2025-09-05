const { ethers } = require("ethers");
require('dotenv').config();

async function directPriceRequest() {
    console.log("🐉 Making direct cross-chain price request...\n");

    // Use environment variables for network connection (ethers v5 syntax)
    const provider = new ethers.providers.JsonRpcProvider(process.env.SONIC_RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    
    console.log(`Connected to: ${process.env.SONIC_RPC_URL}`);
    console.log(`Wallet: ${wallet.address}`);
    
    // Oracle contract info
    const oracleAddress = "0x692E3212AAF12c715ca49e3e8Ff909ca6A4F7777";
    const arbitrumEid = 30110;
    
    // Basic ABI for the functions we need
    const oracleAbi = [
        "function requestPrice(uint32 _targetEid, bytes calldata _extraOptions) external payable returns (tuple(bytes32 guid, uint64 nonce, MessagingFee fee))",
        "function quoteFee(uint32 _targetEid, bytes calldata _extraOptions) external view returns (tuple(uint256 nativeFee, uint256 lzTokenFee))",
        "function activePeers(uint32) external view returns (bool)",
        "function peerOracles(uint32) external view returns (address)",
        "function readChannel() external view returns (uint32)",
        "event PriceRequested(bytes32 indexed guid, uint32 indexed targetEid, address indexed sender, uint256 fee)"
    ];
    
    const oracle = new ethers.Contract(oracleAddress, oracleAbi, wallet);
    
    try {
        // Check configuration
        console.log("Checking configuration...");
        const isActive = await oracle.activePeers(arbitrumEid);
        const peerOracle = await oracle.peerOracles(arbitrumEid);
        const readChannel = await oracle.readChannel();
        
        console.log(`Arbitrum peer active: ${isActive}`);
        console.log(`Peer oracle: ${peerOracle}`);
        console.log(`Read channel: ${readChannel}\n`);
        
        if (!isActive) throw new Error("Arbitrum peer not active");
        
        // Quote fee
        console.log("Quoting fee...");
        const fee = await oracle.quoteFee(arbitrumEid, "0x");
        const feeInEther = ethers.utils.formatEther(fee.nativeFee);
        console.log(`Fee: ${feeInEther} S\n`);
        
        // Check balance
        const balance = await wallet.provider.getBalance(wallet.address);
        const balanceInEther = ethers.utils.formatEther(balance);
        console.log(`Balance: ${balanceInEther} S`);
        
        if (balance.lt(fee.nativeFee)) {
            throw new Error(`Insufficient balance. Need ${feeInEther} S`);
        }
        
        // Make the request
        console.log("\nSending cross-chain request...");
        const tx = await oracle.requestPrice(arbitrumEid, "0x", {
            value: fee.nativeFee,
            gasLimit: 400000
        });
        
        console.log(`Transaction: ${tx.hash}`);
        console.log("Waiting for confirmation...");
        
        const receipt = await tx.wait();
        console.log(`✅ Confirmed in block ${receipt.blockNumber}`);
        console.log(`Gas used: ${receipt.gasUsed}`);
        
        // Parse events
        receipt.logs.forEach((log, index) => {
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
        
        console.log("\n🎉 Cross-chain price request sent successfully!");
        console.log("⏳ Price data should be received via LayerZero shortly...");
        
    } catch (error) {
        console.error("\n❌ Error:", error.message);
        if (error.reason) console.error("Reason:", error.reason);
    }
}

directPriceRequest().catch(console.error);
