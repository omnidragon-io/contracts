use clap::{Arg, Command};
use ethers::types::{Address, H256};
use hex;
use indicatif::{ProgressBar, ProgressStyle};
use rayon::prelude::*;
use sha3::{Digest, Keccak256};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;
use std::io::{self, Write};

const BATCH_SIZE: u64 = 1_000_000;

#[derive(Debug)]
struct VanityConfig {
    factory: Address,
    bytecode_hash: H256,
    starts_with: String,
    ends_with: String,
    threads: usize,
}

fn main() {
    let matches = Command::new("Dragon Vanity Address Generator")
        .version("1.0")
        .author("0xakita.eth")
        .about("Generates vanity addresses for omniDRAGON token using CREATE2")
        .arg(
            Arg::new("factory")
                .long("factory")
                .value_name("ADDRESS")
                .help("CREATE2 factory contract address")
                .default_value("0xAA28020DDA6b954D16208eccF873D79AC6533833")
                .required(false),
        )
        .arg(
            Arg::new("bytecode-hash")
                .long("bytecode-hash")
                .value_name("HASH")
                .help("Keccak256 hash of the contract bytecode")
                .required(true),
        )
        .arg(
            Arg::new("starts-with")
                .long("starts-with")
                .value_name("HEX")
                .help("Address should start with this hex pattern")
                .default_value("69")
                .required(false),
        )
        .arg(
            Arg::new("ends-with")
                .long("ends-with")
                .value_name("HEX")
                .help("Address should end with this hex pattern")
                .default_value("7777")
                .required(false),
        )
        .arg(
            Arg::new("threads")
                .long("threads")
                .value_name("NUM")
                .help("Number of threads to use")
                .default_value("0")
                .required(false),
        )
        .get_matches();

    // Parse arguments
    let factory_str = matches.get_one::<String>("factory").unwrap();
    let bytecode_hash_str = matches.get_one::<String>("bytecode-hash").unwrap();
    let starts_with = matches.get_one::<String>("starts-with").unwrap().to_lowercase();
    let ends_with = matches.get_one::<String>("ends-with").unwrap().to_lowercase();
    let threads: usize = matches.get_one::<String>("threads").unwrap().parse().unwrap_or(0);

    // Parse addresses and hashes
    let factory: Address = factory_str.parse().expect("Invalid factory address");
    let bytecode_hash: H256 = bytecode_hash_str.parse().expect("Invalid bytecode hash");

    let config = VanityConfig {
        factory,
        bytecode_hash,
        starts_with,
        ends_with,
        threads: if threads == 0 { num_cpus::get() } else { threads },
    };

    println!("🐉 Dragon Vanity Address Generator");
    println!("==================================");
    println!("Factory: {:#x}", config.factory);
    println!("Bytecode Hash: {:#x}", config.bytecode_hash);
    println!("Pattern: 0x{}...{}", config.starts_with, config.ends_with);
    println!("Threads: {}", config.threads);
    println!();

    // Set up thread pool
    rayon::ThreadPoolBuilder::new()
        .num_threads(config.threads)
        .build_global()
        .unwrap();

    let start_time = Instant::now();
    let found = Arc::new(AtomicBool::new(false));
    let attempts = Arc::new(AtomicU64::new(0));

    // Progress bar
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.green} [{elapsed_precise}] {msg} | Rate: {per_sec}")
            .unwrap(),
    );

    // Start search with limited range that we can extend if needed
    let max_batches = 100_000; // This gives us 100 billion attempts total
    let result = (0u64..max_batches)
        .into_par_iter()
        .map(|batch| {
            let batch_start = batch * BATCH_SIZE;
            search_batch(&config, batch_start, BATCH_SIZE, &found, &attempts)
        })
        .find_any(|result| result.is_some());

    if let Some(Some((salt, address))) = result {
        pb.finish_with_message("Found!");
        
        println!();
        println!("🎉 SUCCESS! Vanity address found!");
        println!("==================================");
        println!("Salt: {:#x}", salt);
        println!("Address: {:#x}", address);
        println!("Pattern: 0x{}...{}", config.starts_with, config.ends_with);
        println!("Time: {:.2}s", start_time.elapsed().as_secs_f64());
        println!("Attempts: {}", attempts.load(Ordering::Relaxed));
        println!();
        println!("📋 UPDATE YOUR DEPLOYMENT SCRIPT:");
        println!("VANITY_SALT = {:#x};", salt);
        println!("EXPECTED_ADDRESS = {:#x};", address);
        println!();
        println!("🚀 Ready to deploy omniDRAGON with vanity address!");
    } else {
        pb.finish_with_message("Search stopped");
        println!("Search stopped or interrupted");
    }
}

fn search_batch(
    config: &VanityConfig,
    start: u64,
    count: u64,
    found: &Arc<AtomicBool>,
    attempts: &Arc<AtomicU64>,
) -> Option<(H256, Address)> {
    for i in 0..count {
        if found.load(Ordering::Relaxed) {
            return None;
        }

        let salt_num = start + i;
        let salt = H256::from_low_u64_be(salt_num);
        let address = compute_create2_address(config.factory, salt, config.bytecode_hash);

        attempts.fetch_add(1, Ordering::Relaxed);

        if check_vanity_pattern(&address, &config.starts_with, &config.ends_with) {
            found.store(true, Ordering::Relaxed);
            return Some((salt, address));
        }

        // Update progress every 50k attempts
        if i % 50_000 == 0 {
            let total_attempts = attempts.load(Ordering::Relaxed);
            if total_attempts % 100_000 == 0 {
                print!("\rAttempts: {} | Searching...", total_attempts);
                io::stdout().flush().unwrap();
            }
        }
    }
    None
}

fn compute_create2_address(factory: Address, salt: H256, bytecode_hash: H256) -> Address {
    let mut hasher = Keccak256::new();
    hasher.update(&[0xff]);
    hasher.update(factory.as_bytes());
    hasher.update(salt.as_bytes());
    hasher.update(bytecode_hash.as_bytes());
    
    let hash = hasher.finalize();
    Address::from_slice(&hash[12..])
}

fn check_vanity_pattern(address: &Address, starts_with: &str, ends_with: &str) -> bool {
    let addr_hex = hex::encode(address.as_bytes()).to_lowercase();
    
    let starts_match = if starts_with.is_empty() {
        true
    } else {
        addr_hex.starts_with(starts_with)
    };
    
    let ends_match = if ends_with.is_empty() {
        true
    } else {
        addr_hex.ends_with(ends_with)
    };
    
    starts_match && ends_match
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vanity_pattern() {
        // Test address: 0x6900000000000000000000000000000000007777
        let test_address = "6900000000000000000000000000000000007777";
        let address_bytes = hex::decode(test_address).unwrap();
        let address = Address::from_slice(&address_bytes);
        
        assert!(check_vanity_pattern(&address, "69", "7777"));
        assert!(!check_vanity_pattern(&address, "70", "7777"));
        assert!(!check_vanity_pattern(&address, "69", "8888"));
    }

    #[test]
    fn test_create2_computation() {
        // Test with known values
        let factory = "0xAA28020DDA6b954D16208eccF873D79AC6533833".parse().unwrap();
        let salt = H256::zero();
        let bytecode_hash = H256::zero();
        
        let address = compute_create2_address(factory, salt, bytecode_hash);
        println!("Test address: {:#x}", address);
        // This should produce a deterministic address
    }
}
