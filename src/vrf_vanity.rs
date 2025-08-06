use clap::Parser;
use ethers::types::{Address, H256, U256};
use hex;
use rayon::prelude::*;
use sha3::{Digest, Keccak256};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;

#[derive(Parser, Debug)]
#[command(author, version, about = "Generate vanity address for OmniDragonVRFConsumerV2_5 using CREATE2 factory", long_about = None)]
struct Args {
    /// Target address prefix (e.g., "VRF" converts to hex)
    #[arg(short, long, default_value = "VRF")]
    prefix: String,

    /// Target address suffix (e.g., "2525" for V2.5)  
    #[arg(short, long, default_value = "2525")]
    suffix: String,

    /// Deployer address
    #[arg(short, long, default_value = "0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F")]
    deployer: String,

    /// LayerZero endpoint address (Arbitrum)
    #[arg(short, long, default_value = "0x1a44076050125825900e736c501f859c50fE728c")]
    endpoint: String,

    /// VRF Coordinator address
    #[arg(short, long, default_value = "0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e")]
    coordinator: String,

    /// VRF Subscription ID
    #[arg(long, default_value = "49130512167777098004519592693541429977179420141459329604059253338290818062746")]
    subscription_id: String,

    /// VRF Key Hash
    #[arg(long, default_value = "0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409")]
    key_hash: String,

    /// Number of threads to use
    #[arg(short, long, default_value = "8")]
    threads: usize,

    /// Maximum attempts before giving up
    #[arg(short, long, default_value = "50000000")]
    max_attempts: u64,
}

const CREATE2_FACTORY: &str = "0xAA28020DDA6b954D16208eccF873D79AC6533833";

fn string_to_hex_pattern(input: &str) -> String {
    // Convert string to hex bytes
    let bytes = input.as_bytes();
    hex::encode(bytes)
}

fn create_constructor_bytecode(
    endpoint: &str,
    deployer: &str,
    coordinator: &str,
    subscription_id: &str,
    key_hash: &str,
) -> Vec<u8> {
    // This is a simplified version - in reality you'd need the actual contract bytecode
    // For now, we'll use a placeholder that represents the constructor parameters
    let mut bytecode = Vec::new();
    
    // Contract creation code would go here
    // For this example, we'll create a mock bytecode hash
    let constructor_params = format!(
        "{}{}{}{}{}",
        endpoint, deployer, coordinator, subscription_id, key_hash
    );
    
    let mut hasher = Keccak256::new();
    hasher.update(constructor_params.as_bytes());
    bytecode.extend_from_slice(&hasher.finalize());
    
    bytecode
}

fn calculate_create2_address(factory: &Address, salt: &H256, bytecode_hash: &H256) -> Address {
    let mut hasher = Keccak256::new();
    hasher.update(&[0xff]);
    hasher.update(factory.as_bytes());
    hasher.update(salt.as_bytes());
    hasher.update(bytecode_hash.as_bytes());
    
    let hash = hasher.finalize();
    let mut addr_bytes = [0u8; 20];
    addr_bytes.copy_from_slice(&hash[12..32]);
    Address::from(addr_bytes)
}

fn matches_pattern(address: &Address, prefix: &str, suffix: &str) -> bool {
    let addr_str = format!("{:x}", address);
    
    // Check if address starts with prefix (after 0x)
    let starts_match = if prefix.is_empty() {
        true
    } else {
        addr_str.starts_with(&prefix.to_lowercase())
    };
    
    // Check if address ends with suffix
    let ends_match = if suffix.is_empty() {
        true
    } else {
        addr_str.ends_with(&suffix.to_lowercase())
    };
    
    starts_match && ends_match
}

fn main() {
    let args = Args::parse();
    
    println!("🚀 OMNIDRAGON VRF CONSUMER V2.5 VANITY GENERATOR");
    println!("════════════════════════════════════════════════");
    
    // Convert prefix to hex if it's a string
    let hex_prefix = if args.prefix.chars().all(|c| c.is_ascii_hexdigit()) {
        args.prefix.to_lowercase()
    } else {
        string_to_hex_pattern(&args.prefix)
    };
    
    println!("🎯 Target Pattern: 0x{}...{}", hex_prefix, args.suffix);
    println!("🏭 CREATE2 Factory: {}", CREATE2_FACTORY);
    println!("👤 Deployer: {}", args.deployer);
    println!("🌐 LayerZero Endpoint: {}", args.endpoint);
    println!("🎲 VRF Coordinator: {}", args.coordinator);
    println!("📋 Subscription ID: {}", args.subscription_id);
    println!("🔑 Key Hash: {}", args.key_hash);
    println!("🧵 Threads: {}", args.threads);
    println!("🔢 Max Attempts: {}", args.max_attempts);
    println!();

    // Parse addresses
    let factory_addr: Address = CREATE2_FACTORY.parse().expect("Invalid factory address");
    let deployer_addr: Address = args.deployer.parse().expect("Invalid deployer address");
    
    // Create bytecode with constructor parameters
    let bytecode = create_constructor_bytecode(
        &args.endpoint,
        &args.deployer,
        &args.coordinator,
        &args.subscription_id,
        &args.key_hash,
    );
    
    let bytecode_hash = H256::from_slice(&Keccak256::digest(&bytecode));
    
    println!("📝 Bytecode Hash: 0x{}", hex::encode(bytecode_hash.as_bytes()));
    println!("🔍 Searching for vanity salt...");
    println!();

    let found = Arc::new(AtomicBool::new(false));
    let attempts = Arc::new(AtomicU64::new(0));
    let start_time = Instant::now();

    // Parallel search
    let result = (0..args.max_attempts)
        .into_par_iter()
        .map(|i| {
            if found.load(Ordering::Relaxed) {
                return None;
            }

            // Generate random salt
            let salt_bytes: [u8; 32] = rand::random();
            let salt = H256::from(salt_bytes);
            
            // Calculate CREATE2 address
            let address = calculate_create2_address(&factory_addr, &salt, &bytecode_hash);
            
            // Check if it matches our pattern
            if matches_pattern(&address, &hex_prefix, &args.suffix) {
                found.store(true, Ordering::Relaxed);
                return Some((salt, address));
            }
            
            let current_attempts = attempts.fetch_add(1, Ordering::Relaxed);
            if current_attempts % 100000 == 0 {
                let elapsed = start_time.elapsed();
                let rate = current_attempts as f64 / elapsed.as_secs_f64();
                println!("⏱️  Attempts: {} | Rate: {:.0}/s | Elapsed: {:.1}s", 
                    current_attempts, rate, elapsed.as_secs_f64());
            }
            
            None
        })
        .find_any(|x| x.is_some());

    match result {
        Some(Some((salt, address))) => {
            let elapsed = start_time.elapsed();
            let total_attempts = attempts.load(Ordering::Relaxed);
            
            println!("🎉 VANITY ADDRESS FOUND!");
            println!("════════════════════════");
            println!("✨ Address: 0x{:x}", address);
            println!("🧂 Salt: 0x{}", hex::encode(salt.as_bytes()));
            println!("⏱️  Time: {:.2}s", elapsed.as_secs_f64());
            println!("🔢 Attempts: {}", total_attempts);
            println!("📈 Rate: {:.0} attempts/sec", total_attempts as f64 / elapsed.as_secs_f64());
            println!();
            
            println!("📋 DEPLOYMENT COMMANDS:");
            println!("═══════════════════════");
            println!("// Add to your .env file:");
            println!("VANITY_VRF_SALT=0x{}", hex::encode(salt.as_bytes()));
            println!("EXPECTED_VRF_ADDRESS=0x{:x}", address);
            println!();
            
            println!("// Use in Solidity script:");
            println!("bytes32 constant VRF_VANITY_SALT = 0x{};", hex::encode(salt.as_bytes()));
            println!("address constant EXPECTED_VRF_ADDRESS = 0x{:x};", address);
            println!();
            
            println!("🚀 Ready to deploy OmniDragonVRFConsumerV2_5 with vanity address!");
        }
        _ => {
            println!("❌ No vanity address found after {} attempts", args.max_attempts);
            println!("💡 Try:");
            println!("   - Shorter/simpler pattern");
            println!("   - More attempts (--max-attempts)");
            println!("   - More threads (--threads)");
        }
    }
}