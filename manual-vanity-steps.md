# 🐉 Manual Vanity Address Generation Steps

If the automated script has issues, follow these manual steps:

## Step 1: Get Bytecode Hash

```bash
npx hardhat run script/GetDragonBytecodeHash.s.sol
```

Look for output like:
```
BYTECODE HASH:
0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

Copy the **64-character hash** (without 0x prefix for some tools).

## Step 2: Build Rust Generator

```bash
cd vanity-generator
cargo build --release
```

## Step 3: Run Vanity Generator

**With the bytecode hash from Step 1:**

```bash
cargo run --release -- \
  --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \
  --bytecode-hash 0x[YOUR_HASH_FROM_STEP_1] \
  --starts-with 69 \
  --ends-with 7777
```

**Example with a real hash:**
```bash
cargo run --release -- \
  --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \
  --bytecode-hash 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef \
  --starts-with 69 \
  --ends-with 7777
```

## Step 4: Update Deployment Script

When the generator finds a vanity address, it will output:
```
Salt: 0xabcd1234...
Address: 0x69abc...7777
```

Update `script/DeployVanityOmniDragon.s.sol`:

```solidity
bytes32 constant VANITY_SALT = 0xabcd1234...; // Use the found salt
address constant EXPECTED_ADDRESS = 0x69abc...7777; // Use the found address
```

## Step 5: Deploy omniDRAGON

Deploy on all chains using the vanity deployment script:

```bash
cd .. # Back to project root

# 1. Deploy on Sonic first (gets 6,942,000 initial supply)
npx hardhat run script/DeployVanityOmniDragon.s.sol --network sonic

# 2. Deploy on other chains (zero initial supply)
npx hardhat run script/DeployVanityOmniDragon.s.sol --network arbitrum
npx hardhat run script/DeployVanityOmniDragon.s.sol --network ethereum  
npx hardhat run script/DeployVanityOmniDragon.s.sol --network base
npx hardhat run script/DeployVanityOmniDragon.s.sol --network avalanche
```

## Alternative: Quick Deploy (No Vanity)

If you want to deploy immediately without vanity:

```bash
npx hardhat run script/DeployOmniDragonSimple.s.sol --network sonic
npx hardhat run script/DeployOmniDragonSimple.s.sol --network arbitrum
# ... etc for other chains
```

## Troubleshooting

### If Hardhat Fails:
- Make sure you're in the project root
- Check that `.env` file exists with proper RPC URLs
- Verify `hardhat.config.ts` is properly configured

### If Rust Compilation Fails:
```bash
# Install Rust if needed
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Update Rust
rustup update

# Try building again
cd vanity-generator
cargo build --release
```

### If Vanity Generation is Slow:
- Use more threads: `--threads 16`
- Use a different pattern: `--starts-with 69 --ends-with 77` (shorter = faster)
- Be patient - vanity generation can take 1-30 minutes depending on luck

### Performance Tips:
- Close other applications to free CPU
- Use `cargo run --release` (not `cargo run`)
- Consider a simpler pattern if it's taking too long
