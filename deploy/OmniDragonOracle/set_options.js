const { ethers } = require('ethers');

async function main() {
    const privateKey = process.env.PRIVATE_KEY;
    const rpcUrl = 'https://base.publicnode.com'\;
    
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    
    const contractAddress = '0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777';
    const abi = [
        {
            "inputs": [{"components": [{"internalType": "uint32", "name": "eid", "type": "uint32"}, {"internalType": "uint16", "name": "msgType", "type": "uint16"}, {"internalType": "bytes", "name": "options", "type": "bytes"}], "internalType": "struct EnforcedOptionParam[]", "name": "_enforcedOptions", "type": "struct EnforcedOptionParam[]"}],
            "name": "setEnforcedOptions",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
        }
    ];
    
    const contract = new ethers.Contract(contractAddress, abi, wallet);
    
    const enforcedOptions = [{
        eid: 30332, // Sonic
        msgType: 1,
        options: '0x000301001505000000000000000000000000000f424000000060'
    }];
    
    console.log('Setting enforced options...');
    const tx = await contract.setEnforcedOptions(enforcedOptions);
    console.log('Transaction sent:', tx.hash);
    
    const receipt = await tx.wait();
    console.log('Transaction confirmed in block:', receipt.blockNumber);
}

main().catch(console.error);
