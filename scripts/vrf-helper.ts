import { ethers } from "hardhat";

async function main() {
    console.log("🎲 VRF Helper - Get Quote and Make Request");
    
    // Connect to Sonic
    const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL_SONIC);
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
    
    const VRF_INTEGRATOR = "0x4cc69C8FEd6d340742a347905ac99DdD5b2B0A90";
    
    // Contract interface with correct function signatures
    const contract = new ethers.Contract(VRF_INTEGRATOR, [
        "function quoteSimple() external view returns ((uint256,uint256))",
        "function quoteWithGas(uint32 gasLimit) external view returns ((uint256,uint256))",
        "function requestRandomWordsSimple(uint32 dstEid) external payable returns (bytes32)",
        "function requestCounter() external view returns (uint256)"
    ], signer);
    
    try {
        console.log("\n💰 Getting fee quotes...");
        
        // Get simple quote
        const simpleQuote = await contract.quoteSimple();
        const simpleFeeETH = ethers.utils.formatEther(simpleQuote[0]);
        console.log(`  Simple Quote: ${simpleFeeETH} ETH`);
        
        // Get quote with custom gas
        const gasQuote = await contract.quoteWithGas(200000);
        const gasFeeETH = ethers.utils.formatEther(gasQuote[0]);
        console.log(`  Custom Gas Quote (200k): ${gasFeeETH} ETH`);
        
        // Get current request counter
        const counter = await contract.requestCounter();
        console.log(`  Current Request Counter: ${counter}`);
        
        // Ask user if they want to make a request
        console.log(`\n🎯 To make a VRF request, run:`);
        console.log(`cast send ${VRF_INTEGRATOR} "requestRandomWordsSimple(uint32)" 30110 --value ${simpleFeeETH}ether --rpc-url $RPC_URL_SONIC --private-key $PRIVATE_KEY --legacy`);
        
        console.log(`\n📊 Or for a safety margin (+10%), use:`);
        const safetyFee = parseFloat(simpleFeeETH) * 1.1;
        console.log(`cast send ${VRF_INTEGRATOR} "requestRandomWordsSimple(uint32)" 30110 --value ${safetyFee.toFixed(6)}ether --rpc-url $RPC_URL_SONIC --private-key $PRIVATE_KEY --legacy`);
        
    } catch (error: any) {
        console.error("❌ Error:", error.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });