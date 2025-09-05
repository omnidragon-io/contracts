use clap::Parser;
use hex;
use rand::RngCore;
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

#[derive(Parser, Debug)]
#[command(name = "oracle-vanity-generator")]
#[command(about = "Generate vanity salt for OmniDragonOracle CREATE2 deployment")]
struct Args {
    /// Target pattern prefix (without 0x)
    #[arg(short, long, default_value = "69")]
    prefix: String,

    /// Target pattern suffix
    #[arg(short, long, default_value = "777")]
    suffix: String,

    /// CREATE2 factory address
    #[arg(short, long, default_value = "0xAA28020DDA6b954D16208eccF873D79AC6533833")]
    factory: String,

    /// Bytecode hash (if known)
    #[arg(short, long)]
    bytecode_hash: Option<String>,

    /// Number of threads to use (0 = all cores)
    #[arg(short, long, default_value = "0")]
    threads: usize,

    /// Print progress every N attempts
    #[arg(long, default_value = "10000000")]
    progress_interval: u64,

    /// Maximum attempts before giving up (0 = infinite)
    #[arg(long, default_value = "0")]
    max_attempts: u64,

    /// Generate example bytecode hash for testing
    #[arg(long)]
    example: bool,
}

#[derive(Serialize, Deserialize, Debug)]
struct VanityResult {
    salt: String,
    address: String,
    bytecode_hash: String,
    factory_address: String,
    attempts: u64,
    pattern: String,
    time_seconds: f64,
    threads_used: usize,
}

fn main() {
    let args = Args::parse();

    if args.example {
        generate_example_bytecode_hash();
        return;
    }

    let bytecode_hash = match args.bytecode_hash {
        Some(hash) => normalize_hex(&hash),
        None => {
            println!("⚠️  No bytecode hash provided. Using example hash for testing.");
            println!("   Use --example to see how to generate a bytecode hash.");
            // Example hash from a simple contract
            "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef".to_string()
        }
    };

    let factory_address = normalize_hex(&args.factory);
    let pattern = format!("0x{}...{}", args.prefix, args.suffix);

    println!("🔍 OmniDragonOracle Vanity Salt Generator");
    println!("═══════════════════════════════════════");
    println!("Target Pattern: {}", pattern);
    println!("Factory Address: {}", factory_address);
    println!("Bytecode Hash: {}", bytecode_hash);

    let thread_count = if args.threads == 0 {
        num_cpus::get()
    } else {
        args.threads
    };

    println!("Threads: {}", thread_count);
    println!("Progress Interval: {} attempts", args.progress_interval);
    println!("");

    // Set up thread pool
    rayon::ThreadPoolBuilder::new()
        .num_threads(thread_count)
        .build_global()
        .unwrap();

    let start_time = Instant::now();
    let found = Arc::new(AtomicBool::new(false));
    let total_attempts = Arc::new(AtomicU64::new(0));

    let result = (0..thread_count).into_par_iter().find_map_any(|thread_id| {
        let mut rng = rand::thread_rng();
        let mut attempts = 0u64;
        let mut local_best = BestMatch::new();

        loop {
            if found.load(Ordering::Relaxed) {
                break;
            }

            if args.max_attempts > 0 && total_attempts.load(Ordering::Relaxed) >= args.max_attempts {
                break;
            }

            // Generate random salt
            let mut salt_bytes = [0u8; 32];
            rng.fill_bytes(&mut salt_bytes);
            let salt = format!("0x{}", hex::encode(salt_bytes));

            // Calculate CREATE2 address
            let address = calculate_create2_address(&factory_address, &salt, &bytecode_hash);

            // Check if it matches our pattern
            if is_perfect_match(&address, &args.prefix, &args.suffix) {
                found.store(true, Ordering::Relaxed);
                let total = total_attempts.fetch_add(attempts, Ordering::Relaxed) + attempts;
                
                let result = VanityResult {
                    salt,
                    address,
                    bytecode_hash: bytecode_hash.clone(),
                    factory_address: factory_address.clone(),
                    attempts: total,
                    pattern: pattern.clone(),
                    time_seconds: start_time.elapsed().as_secs_f64(),
                    threads_used: thread_count,
                };

                return Some(result);
            }

            // Track best partial match
            let score = calculate_match_score(&address, &args.prefix, &args.suffix);
            if score > local_best.score {
                local_best = BestMatch {
                    address,
                    salt,
                    score,
                    attempts: total_attempts.load(Ordering::Relaxed) + attempts,
                };
            }

            attempts += 1;

            // Progress reporting
            if attempts % args.progress_interval == 0 {
                let total = total_attempts.fetch_add(attempts, Ordering::Relaxed) + attempts;
                let elapsed = start_time.elapsed().as_secs_f64();
                let rate = total as f64 / elapsed;

                println!(
                    "Thread {}: {} attempts, {:.0} attempts/sec, Best: {} (score: {})",
                    thread_id, total, rate, local_best.address, local_best.score
                );

                attempts = 0; // Reset local counter
            }
        }

        None
    });

    match result {
        Some(result) => {
            println!("\n🎉 PERFECT MATCH FOUND!");
            println!("═══════════════════════");
            println!("Address: {}", result.address);
            println!("Salt: {}", result.salt);
            println!("Attempts: {}", result.attempts);
            println!("Time: {:.2} seconds", result.time_seconds);
            println!("Rate: {:.0} attempts/second", result.attempts as f64 / result.time_seconds);
            
            // Save to file
            match save_result_to_file(&result) {
                Ok(filename) => println!("Result saved to: {}", filename),
                Err(e) => eprintln!("Error saving result: {}", e),
            }
        }
        None => {
            let total = total_attempts.load(Ordering::Relaxed);
            let elapsed = start_time.elapsed().as_secs_f64();
            
            println!("\n❌ Perfect match not found");
            println!("Total attempts: {}", total);
            println!("Time: {:.2} seconds", elapsed);
            if total > 0 {
                println!("Rate: {:.0} attempts/second", total as f64 / elapsed);
            }
            println!("Try running longer or adjusting the pattern.");
        }
    }
}

#[derive(Clone)]
struct BestMatch {
    address: String,
    salt: String,
    score: u32,
    attempts: u64,
}

impl BestMatch {
    fn new() -> Self {
        Self {
            address: "0x0000000000000000000000000000000000000000".to_string(),
            salt: "0x0000000000000000000000000000000000000000000000000000000000000000".to_string(),
            score: 0,
            attempts: 0,
        }
    }
}

fn calculate_create2_address(factory: &str, salt: &str, bytecode_hash: &str) -> String {
    // CREATE2 address calculation: keccak256(0xff ++ factory ++ salt ++ bytecode_hash)[12:]
    let factory_bytes = hex::decode(&factory[2..]).expect("Invalid factory address");
    let salt_bytes = hex::decode(&salt[2..]).expect("Invalid salt");
    let bytecode_hash_bytes = hex::decode(&bytecode_hash[2..]).expect("Invalid bytecode hash");

    let mut input = Vec::new();
    input.push(0xff); // CREATE2 prefix
    input.extend_from_slice(&factory_bytes);
    input.extend_from_slice(&salt_bytes);
    input.extend_from_slice(&bytecode_hash_bytes);

    let hash = Keccak256::digest(&input);
    let address_bytes = &hash[12..]; // Take last 20 bytes
    
    format!("0x{}", hex::encode(address_bytes))
}

fn is_perfect_match(address: &str, prefix: &str, suffix: &str) -> bool {
    let addr = address.to_lowercase();
    let addr_without_prefix = &addr[2..]; // Remove "0x"
    
    addr_without_prefix.starts_with(&prefix.to_lowercase()) &&
    addr_without_prefix.ends_with(&suffix.to_lowercase())
}

fn calculate_match_score(address: &str, prefix: &str, suffix: &str) -> u32 {
    let addr = address.to_lowercase();
    let addr_without_prefix = &addr[2..];
    let target_prefix = prefix.to_lowercase();
    let target_suffix = suffix.to_lowercase();
    
    let mut score = 0u32;
    
    // Score prefix match
    let prefix_match_len = addr_without_prefix
        .chars()
        .zip(target_prefix.chars())
        .take_while(|(a, b)| a == b)
        .count();
    score += prefix_match_len as u32 * 10;
    
    // Score suffix match
    let suffix_match_len = addr_without_prefix
        .chars()
        .rev()
        .zip(target_suffix.chars().rev())
        .take_while(|(a, b)| a == b)
        .count();
    score += suffix_match_len as u32 * 10;
    
    score
}

fn normalize_hex(hex_str: &str) -> String {
    let clean = if hex_str.starts_with("0x") {
        &hex_str[2..]
    } else {
        hex_str
    };
    
    format!("0x{}", clean.to_lowercase())
}

fn save_result_to_file(result: &VanityResult) -> Result<String, Box<dyn std::error::Error>> {
    let filename = format!("oracle-vanity-result-{}.json", 
        chrono::Utc::now().format("%Y%m%d-%H%M%S"));
    
    let json = serde_json::to_string_pretty(result)?;
    std::fs::write(&filename, json)?;
    
    Ok(filename)
}

fn generate_example_bytecode_hash() {
    println!("📝 Example: How to generate bytecode hash");
    println!("═══════════════════════════════════════");
    println!("");
    println!("1. Compile your contract:");
    println!("   forge build contracts/core/oracles/YourOracle.sol");
    println!("");
    println!("2. Get the bytecode from compilation artifacts:");
    println!("   cat out/YourOracle.sol/YourOracle.json | jq -r '.bytecode.object'");
    println!("");
    println!("3. Generate constructor arguments (ABI encoded):");
    println!("   cast abi-encode 'constructor(address,address,address,uint8)' \\");
    println!("     0x6949936442425f4137807Ac5d269e6Ef66d50777 \\  # registry");
    println!("     0x1234567890123456789012345678901234567890 \\  # delegate");
    println!("     0x1234567890123456789012345678901234567890 \\  # owner");
    println!("     0                                            # mode (PRIMARY)");
    println!("");
    println!("4. Combine bytecode + constructor args and hash:");
    println!("   FULL_BYTECODE=\"$BYTECODE$CONSTRUCTOR_ARGS\"");
    println!("   echo $FULL_BYTECODE | cast keccak");
    println!("");
    println!("5. Use the resulting hash with this tool:");
    println!("   cargo run -- --bytecode-hash 0x[HASH] --prefix 69 --suffix 777");
    println!("");
    println!("💡 Tip: The bytecode hash changes with constructor arguments,");
    println!("   so generate it for your specific deployment parameters!");
}

impl std::fmt::Display for VanityResult {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        writeln!(f, "🎯 Vanity Salt Result")?;
        writeln!(f, "═══════════════════")?;
        writeln!(f, "Pattern: {}", self.pattern)?;
        writeln!(f, "Address: {}", self.address)?;
        writeln!(f, "Salt: {}", self.salt)?;
        writeln!(f, "Attempts: {}", self.attempts)?;
        writeln!(f, "Time: {:.2}s", self.time_seconds)?;
        writeln!(f, "Rate: {:.0} attempts/sec", self.attempts as f64 / self.time_seconds)?;
        writeln!(f, "Threads: {}", self.threads_used)
    }
}