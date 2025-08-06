import { ethers } from "hardhat";

async function main() {
    console.log("Computing ChainlinkVRFIntegratorV2_5 bytecode hash...");
    
    // Registry address (same as used in deployment script)
    const registryAddress = "0xB812B719A00123310751c7A82dEba38777cf0cC8";
    
    console.log(`Registry Address: ${registryAddress}`);
    
    // Get the contract factory
    const VRFIntegratorFactory = await ethers.getContractFactory("ChainlinkVRFIntegratorV2_5");
    
    // Encode constructor arguments
    const constructorArgs = ethers.utils.defaultAbiCoder.encode(
        ["address"],
        [registryAddress]
    );
    
    // Get creation bytecode with constructor arguments
    const creationBytecode = ethers.utils.concat([
        VRFIntegratorFactory.bytecode,
        constructorArgs
    ]);
    
    // Compute keccak256 hash
    const bytecodeHash = ethers.utils.keccak256(creationBytecode);
    
    console.log("Bytecode Hash:", bytecodeHash);
    console.log("\nUpdate the Rust vanity generator with this hash:");
    console.log(`const VRF_INTEGRATOR_BYTECODE_HASH: &str = "${bytecodeHash}";`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });