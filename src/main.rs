use clap::Parser;
use ethers::types::{Address, H256, U256};
use hex;
use rayon::prelude::*;
use sha3::{Digest, Keccak256};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Target address prefix (e.g., "69")
    #[arg(short, long, default_value = "69")]
    prefix: String,

    /// Target address suffix (e.g., "0777")  
    #[arg(short, long, default_value = "0777")]
    suffix: String,

    /// Deployer address
    #[arg(short, long)]
    deployer: String,

    /// Contract bytecode hash (32 bytes hex)
    #[arg(short, long, default_value = "a1b2c3d4e5f67890123456789012345678901234567890123456789012345678")]
    bytecode_hash: String,

    /// Number of threads to use
    #[arg(short, long, default_value = "8")]
    threads: usize,

    /// Maximum attempts before giving up
    #[arg(short, long, default_value = "10000000")]
    max_attempts: u64,
}

fn main() {
    let args = Args::parse();
    
    println!("🚀 OMNIDRAGON VANITY ADDRESS GENERATOR");
    println!("═══════════════════════════════════════");
    println!("🎯 Target: 0x{}...{}", args.prefix, args.suffix);
    println!("👤 Deployer: {}", args.deployer);
    println!("🔗 Bytecode Hash: 0x{}", args.bytecode_hash);
    println!("🧵 Threads: {}", args.threads);
    println!("🔢 Max Attempts: {}", args.max_attempts);
    println!();

    // Parse deployer address
    let deployer: Address = args.deployer.parse().expect("Invalid deployer address");
    
    // Parse bytecode hash
    let bytecode_hash_bytes = hex::decode(&args.bytecode_hash)
        .expect("Invalid bytecode hash");
    if bytecode_hash_bytes.len() != 32 {
        panic!("Bytecode hash must be exactly 32 bytes");
    }
    let bytecode_hash = H256::from_slice(&bytecode_hash_bytes);

    // Setup parallel search
    let found = Arc::new(AtomicBool::new(false));
    let attempts = Arc::new(AtomicU64::new(0));
    let start_time = Instant::now();

    // Progress reporting
    let progress_attempts = Arc::clone(&attempts);
    let progress_found = Arc::clone(&found);
    std::thread::spawn(move || {
        let mut last_count = 0;
        while !progress_found.load(Ordering::Relaxed) {
            std::thread::sleep(std::time::Duration::from_secs(5));
            let current = progress_attempts.load(Ordering::Relaxed);
            let rate = (current - last_count) / 5;
            println!("📊 Attempts: {} | Rate: {}/s", current, rate);
            last_count = current;
        }
    });

    // Parallel vanity search
    let result = (0..args.threads)
        .into_par_iter()
        .find_map_any(|thread_id| {
            search_vanity_address(
                thread_id,
                &deployer,
                &bytecode_hash,
                &args.prefix,
                &args.suffix,
                args.max_attempts / args.threads as u64,
                Arc::clone(&found),
                Arc::clone(&attempts),
            )
        });

    let elapsed = start_time.elapsed();
    let total_attempts = attempts.load(Ordering::Relaxed);

    match result {
        Some((salt, address)) => {
            println!("\n🎉 VANITY ADDRESS FOUND!");
            println!("═════════════════════════");
            println!("📍 Address: {:#x}", address);
            println!("🧂 Salt: {:#x}", salt);
            println!("⏱️  Time: {:.2}s", elapsed.as_secs_f64());
            println!("🔢 Attempts: {}", total_attempts);
            println!("⚡ Rate: {:.0} attempts/s", total_attempts as f64 / elapsed.as_secs_f64());
            
            // Generate deployment script
            generate_deployment_script(&salt, &address, &args.deployer);
        }
        None => {
            println!("\n❌ No vanity address found after {} attempts", total_attempts);
            println!("💡 Try:");
            println!("   - Shorter pattern (e.g., --prefix 69 --suffix 77)");
            println!("   - More threads (--threads 16)");
            println!("   - Higher max attempts (--max-attempts 50000000)");
        }
    }
}

fn search_vanity_address(
    thread_id: usize,
    deployer: &Address,
    bytecode_hash: &H256,
    prefix: &str,
    suffix: &str,
    max_attempts: u64,
    found: Arc<AtomicBool>,
    global_attempts: Arc<AtomicU64>,
) -> Option<(H256, Address)> {
    let mut rng = rand::thread_rng();
    let prefix_lower = prefix.to_lowercase();
    let suffix_lower = suffix.to_lowercase();

    for i in 0..max_attempts {
        if found.load(Ordering::Relaxed) {
            return None; // Another thread found it
        }

        // Generate random salt
        let salt_bytes: [u8; 32] = rand::random();
        let salt = H256::from(salt_bytes);

        // Calculate CREATE2 address
        let address = calculate_create2_address(deployer, &salt, bytecode_hash);
        let address_str = format!("{:#x}", address);
        let address_lower = address_str.to_lowercase();

        // Check if it matches our pattern
        if address_lower.starts_with(&format!("0x{}", prefix_lower)) &&
           address_lower.ends_with(&suffix_lower) {
            
            found.store(true, Ordering::Relaxed);
            println!("\n🎯 Thread {} found match!", thread_id);
            return Some((salt, address));
        }

        // Update global counter every 1000 attempts
        if i % 1000 == 0 {
            global_attempts.fetch_add(1000, Ordering::Relaxed);
        }
    }

    global_attempts.fetch_add(max_attempts % 1000, Ordering::Relaxed);
    None
}

fn calculate_create2_address(deployer: &Address, salt: &H256, bytecode_hash: &H256) -> Address {
    // CREATE2 address = keccak256(0xff + deployer + salt + bytecode_hash)[12:]
    let mut hasher = Keccak256::new();
    hasher.update([0xff]);
    hasher.update(deployer.as_bytes());
    hasher.update(salt.as_bytes());
    hasher.update(bytecode_hash.as_bytes());
    
    let hash = hasher.finalize();
    Address::from_slice(&hash[12..])
}

fn generate_deployment_script(salt: &H256, address: &Address, deployer: &str) {
    let script_content = format!(
        "// GENERATED VANITY DEPLOYMENT SCRIPT\n\
// Deploy OmniDragonRegistry to vanity address: {:#x}\n\
\n\
import {{ ethers }} from 'hardhat';\n\
\n\
async function main() {{\n\
    console.log('🚀 Deploying OmniDragonRegistry to vanity address...');\n\
    \n\
    const [signer] = await ethers.getSigners();\n\
    console.log('Deployer:', signer.address);\n\
    \n\
    // Vanity deployment parameters\n\
    const salt = '{:#x}';\n\
    const expectedAddress = '{:#x}';\n\
    const deployerAddress = '{}';\n\
    \n\
    console.log('Expected address:', expectedAddress);\n\
    console.log('Salt:', salt);\n\
    \n\
    // Get contract factory\n\
    const Registry = await ethers.getContractFactory('OmniDragonRegistry');\n\
    \n\
    // Constructor args\n\
    const constructorArgs = [deployerAddress];\n\
    \n\
    // Calculate CREATE2 address to verify\n\
    const initCode = Registry.getDeployTransaction(...constructorArgs).data;\n\
    const bytecodeHash = ethers.utils.keccak256(initCode);\n\
    \n\
    const calculatedAddress = ethers.utils.getCreate2Address(\n\
        deployerAddress,\n\
        salt,\n\
        bytecodeHash\n\
    );\n\
    \n\
    console.log('Calculated address:', calculatedAddress);\n\
    \n\
    if (calculatedAddress.toLowerCase() !== expectedAddress.toLowerCase()) {{\n\
        console.warn('⚠️  Address mismatch! Contract bytecode may have changed.');\n\
        console.log('Expected:', expectedAddress);\n\
        console.log('Calculated:', calculatedAddress);\n\
    }}\n\
    \n\
    // Deploy using CREATE2\n\
    const registry = await Registry.deploy(...constructorArgs, {{\n\
        salt: salt,\n\
        gasLimit: 3000000\n\
    }});\n\
    \n\
    await registry.deployed();\n\
    \n\
    console.log('🎉 Registry deployed!');\n\
    console.log('Address:', registry.address);\n\
    console.log('Transaction:', registry.deployTransaction.hash);\n\
    \n\
    // Verify deployment\n\
    const owner = await registry.owner();\n\
    \n\
    console.log('✅ Verified:');\n\
    console.log('   Owner:', owner);\n\
    \n\
    return registry.address;\n\
}}\n\
\n\
main().catch(console.error);\n",
        address, salt, address, deployer
    );

    std::fs::write("scripts/deploy-vanity-registry.js", script_content)
        .expect("Failed to write deployment script");

    println!("✅ Deployment script saved: scripts/deploy-vanity-registry.js");
    println!("\n🚀 NEXT STEPS:");
    println!("1. npx hardhat compile");
    println!("2. npx hardhat run scripts/deploy-vanity-registry.js --network arbitrum");
    println!("3. Configure LayerZero V2 endpoints via your vanity registry!");
}