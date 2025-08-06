use clap::Parser;
// Removed unused imports
use hex;
use rayon::prelude::*;
use sha3::{Digest, Keccak256};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;

#[derive(Parser, Debug)]
#[command(author, version, about = "Generate vanity address for ChainlinkVRFIntegratorV2_5 using CREATE2 factory", long_about = None)]
struct Args {
    /// Target address prefix (e.g., "69" for hex)
    #[arg(short, long, default_value = "69")]
    prefix: String,

    /// Target address suffix (e.g., "a777")  
    #[arg(short, long, default_value = "a777")]
    suffix: String,

    /// Deployer address
    #[arg(short, long, default_value = "0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F")]
    deployer: String,

    /// Registry address (OmniDragonRegistry)
    #[arg(short, long, default_value = "0xB812B719A00123310751c7A82dEba38777cf0cC8")]
    registry: String,

    /// Owner address
    #[arg(short, long, default_value = "0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F")]
    owner: String,

    /// Number of threads to use
    #[arg(short, long, default_value = "8")]
    threads: usize,

    /// Maximum attempts before giving up
    #[arg(short, long, default_value = "50000000")]
    max_attempts: u64,
}

const CREATE2_FACTORY: &str = "0xAA28020DDA6b954D16208eccF873D79AC6533833";

// ChainlinkVRFIntegratorV2_5 bytecode hash (computed from actual contract)
const VRF_INTEGRATOR_BYTECODE_HASH: &str = "0x155b7a044a741036ad9fb7dfa1f5f0194ac8e3e0aa416e1c0755c718bf2ad11c";

fn string_to_hex_prefix(s: &str) -> String {
    if s.chars().all(|c| c.is_ascii_hexdigit()) {
        s.to_lowercase()
    } else {
        // Convert string to hex
        hex::encode(s.as_bytes())
    }
}

fn compute_create2_address(factory: &str, salt: &str, bytecode_hash: &str) -> String {
    let factory_bytes = hex::decode(&factory[2..]).expect("Invalid factory address");
    let salt_bytes = hex::decode(&salt[2..]).expect("Invalid salt");
    let bytecode_hash_bytes = hex::decode(&bytecode_hash[2..]).expect("Invalid bytecode hash");
    
    let mut hasher = Keccak256::new();
    hasher.update(&[0xff]);
    hasher.update(&factory_bytes);
    hasher.update(&salt_bytes);
    hasher.update(&bytecode_hash_bytes);
    
    let result = hasher.finalize();
    let address = &result[12..]; // Take last 20 bytes
    format!("0x{}", hex::encode(address))
}

fn generate_random_salt() -> String {
    use rand::Rng;
    let mut rng = rand::thread_rng();
    let salt: [u8; 32] = rng.gen();
    format!("0x{}", hex::encode(salt))
}

fn check_vanity_pattern(address: &str, prefix: &str, suffix: &str) -> bool {
    let addr_lower = address.to_lowercase();
    let prefix_lower = prefix.to_lowercase();
    let suffix_lower = suffix.to_lowercase();
    
    if !addr_lower.starts_with(&format!("0x{}", prefix_lower)) {
        return false;
    }
    
    if !addr_lower.ends_with(&suffix_lower) {
        return false;
    }
    
    true
}

fn _compute_vrf_integrator_bytecode_hash(registry: &str) -> String {
    // For now, we'll need to compute this by getting the actual bytecode
    // This is a placeholder implementation
    println!("Computing bytecode hash for ChainlinkVRFIntegratorV2_5...");
    println!("Registry: {}", registry);
    
    // This would need to be computed from the actual contract bytecode + constructor args
    // For now, using a placeholder
    "0x1234567890123456789012345678901234567890123456789012345678901234".to_string()
}

fn search_vanity_salt(
    factory: &str,
    bytecode_hash: &str,
    prefix: &str,
    suffix: &str,
    max_attempts: u64,
    thread_count: usize,
) -> Option<(String, String, u64, f64)> {
    let found = Arc::new(AtomicBool::new(false));
    let attempts = Arc::new(AtomicU64::new(0));
    let start_time = Instant::now();
    
    println!("🔍 Searching for vanity salt...");
    println!();
    
    let result = (0..thread_count)
        .into_par_iter()
        .map(|_| {
            let mut local_attempts = 0u64;
            let local_found = Arc::clone(&found);
            let local_attempts_counter = Arc::clone(&attempts);
            
            while !local_found.load(Ordering::Relaxed) && local_attempts < max_attempts / thread_count as u64 {
                let salt = generate_random_salt();
                let address = compute_create2_address(factory, &salt, bytecode_hash);
                
                local_attempts += 1;
                
                if local_attempts % 10000 == 0 {
                    let total_attempts = local_attempts_counter.fetch_add(10000, Ordering::Relaxed) + 10000;
                    let elapsed = start_time.elapsed().as_secs_f64();
                    let rate = if elapsed > 0.0 { total_attempts as f64 / elapsed } else { 0.0 };
                    
                    print!("\r⏱️  Attempts: {} | Rate: {:.0}/s | Elapsed: {:.1}s", 
                           total_attempts, rate, elapsed);
                    std::io::Write::flush(&mut std::io::stdout()).unwrap();
                }
                
                if check_vanity_pattern(&address, prefix, suffix) {
                    local_found.store(true, Ordering::Relaxed);
                    let elapsed = start_time.elapsed().as_secs_f64();
                    let total_attempts = local_attempts_counter.load(Ordering::Relaxed) + local_attempts;
                    return Some((salt, address, total_attempts, elapsed));
                }
            }
            
            local_attempts_counter.fetch_add(local_attempts, Ordering::Relaxed);
            None
        })
        .find_any(|x| x.is_some());
    
    match result {
        Some(Some(result)) => Some(result),
        _ => None,
    }
}

fn main() {
    let args = Args::parse();
    
    println!("🚀 OMNIDRAGON VRF INTEGRATOR V2.5 VANITY GENERATOR");
    println!("════════════════════════════════════════════════");
    println!("🎯 Target Pattern: 0x{}...{}", args.prefix, args.suffix);
    println!("🏭 CREATE2 Factory: {}", CREATE2_FACTORY);
    println!("👤 Deployer: {}", args.deployer);
    println!("📋 Registry: {}", args.registry);
    println!("👑 Owner: {}", args.owner);
    println!("🧵 Threads: {}", args.threads);
    println!("🔢 Max Attempts: {}", args.max_attempts);
    println!();
    
    // Use the computed bytecode hash for ChainlinkVRFIntegratorV2_5
    let bytecode_hash = VRF_INTEGRATOR_BYTECODE_HASH;
    
    println!("📝 Bytecode Hash: {}", bytecode_hash);
    
    let hex_prefix = string_to_hex_prefix(&args.prefix);
    let hex_suffix = string_to_hex_prefix(&args.suffix);
    
    match search_vanity_salt(
        CREATE2_FACTORY,
        &bytecode_hash,
        &hex_prefix,
        &hex_suffix,
        args.max_attempts,
        args.threads,
    ) {
        Some((salt, address, attempts, elapsed)) => {
            println!();
            println!("🎉 VANITY ADDRESS FOUND!");
            println!("════════════════════════");
            println!("✨ Address: {}", address);
            println!("🧂 Salt: {}", salt);
            println!("⏱️  Time: {:.2}s", elapsed);
            println!("🔢 Attempts: {}", attempts);
            println!("📈 Rate: {:.0} attempts/sec", attempts as f64 / elapsed);
            println!();
            
            println!("📋 DEPLOYMENT COMMANDS:");
            println!("═══════════════════════");
            println!("// Add to your .env file:");
            println!("VANITY_VRF_INTEGRATOR_SALT={}", salt);
            println!("EXPECTED_VRF_INTEGRATOR_ADDRESS={}", address);
            println!();
            println!("// Use in Solidity script:");
            println!("bytes32 constant VRF_INTEGRATOR_VANITY_SALT = {};", salt);
            println!("address constant EXPECTED_VRF_INTEGRATOR_ADDRESS = {};", address);
            println!();
            println!("🚀 Ready to deploy ChainlinkVRFIntegratorV2_5 with vanity address!");
        }
        None => {
            println!();
            println!("❌ No vanity address found within {} attempts", args.max_attempts);
            println!("💡 Try:");
            println!("  - Increasing max attempts (--max-attempts)");
            println!("  - Using shorter patterns");
            println!("  - More threads (--threads)");
        }
    }
    
    println!();
    println!("💡 Tips for better results:");
    println!("  - Use shorter patterns (2-4 chars)");
    println!("  - Hex patterns are faster than string conversion");
    println!("  - More threads = faster search");
    println!();
    println!("🔗 Next steps:");
    println!("  1. Update script/DeployVanityVRFIntegrator.s.sol with generated salt");
    println!("  2. Run: forge script script/DeployVanityVRFIntegrator.s.sol --rpc-url $RPC_URL_SONIC --broadcast");
}