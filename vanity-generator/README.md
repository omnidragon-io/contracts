# 🐉 Dragon Vanity Address Generator

Fast Rust-based vanity address generator for omniDRAGON token deployment.

## Quick Start

### 1. Get Bytecode Hash
```bash
# From the main project directory
npx hardhat run script/GetDragonBytecodeHash.s.sol
```

This will output:
- The bytecode hash needed for vanity generation
- The exact command to run the Rust generator

### 2. Generate Vanity Salt
```bash
cd vanity-generator
cargo run --release -- \
  --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \
  --bytecode-hash 0x[HASH_FROM_STEP_1] \
  --starts-with 69 \
  --ends-with 7777
```

### 3. Deploy with Vanity Address
Update `script/DeployVanityOmniDragon.s.sol` with:
- `VANITY_SALT = 0x[FOUND_SALT];`
- `EXPECTED_ADDRESS = 0x[FOUND_ADDRESS];`

Then deploy:
```bash
npx hardhat run script/DeployVanityOmniDragon.s.sol --network sonic
```

## Features

- ⚡ **Multi-threaded**: Uses all CPU cores for maximum speed
- 🎯 **Pattern Matching**: Flexible start/end pattern support
- 📊 **Progress Tracking**: Real-time attempt counter
- 🔒 **CREATE2 Compatible**: Works with any CREATE2 factory
- 🚀 **Optimized**: Release build with LTO for maximum performance

## Configuration

### Command Line Options

```
Options:
  --factory <ADDRESS>        CREATE2 factory address [default: 0xAA28...]
  --bytecode-hash <HASH>     Keccak256 hash of contract bytecode [required]
  --starts-with <HEX>        Address prefix pattern [default: 69]
  --ends-with <HEX>          Address suffix pattern [default: 7777]
  --threads <NUM>            Number of threads [default: auto-detect]
```

### Examples

**Basic vanity (0x69...7777):**
```bash
cargo run --release -- --bytecode-hash 0xabcd...
```

**Custom pattern (0x420...cafe):**
```bash
cargo run --release -- \
  --bytecode-hash 0xabcd... \
  --starts-with 420 \
  --ends-with cafe
```

**High-performance (16 threads):**
```bash
cargo run --release -- \
  --bytecode-hash 0xabcd... \
  --threads 16
```

## Performance

Expected generation times for `0x69...7777` pattern:
- **8-core CPU**: ~1-10 minutes
- **16-core CPU**: ~30 seconds - 5 minutes  
- **32-core CPU**: ~15 seconds - 2 minutes

> Note: Times vary significantly based on luck and CPU performance

## Output

When successful, the generator outputs:
```
🎉 SUCCESS! Vanity address found!
==================================
Salt: 0x1234567890abcdef...
Address: 0x69abc...7777
Pattern: 0x69...7777
Time: 127.32s
Attempts: 15,728,640

📋 UPDATE YOUR DEPLOYMENT SCRIPT:
VANITY_SALT = 0x1234567890abcdef...;
EXPECTED_ADDRESS = 0x69abc...7777;

🚀 Ready to deploy omniDRAGON with vanity address!
```

## Integration with omniDRAGON

This generator is specifically designed for the omniDRAGON token with:
- ✅ Same vanity address on all chains
- ✅ 6,942,000 DRAGON initial supply on Sonic
- ✅ LayerZero V2 OFT compatibility
- ✅ Registry integration

## Build & Install

```bash
# Development build
cargo build

# Optimized release build  
cargo build --release

# Run tests
cargo test
```
