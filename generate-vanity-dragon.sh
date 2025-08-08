#!/bin/bash

# 🐉 Dragon Vanity Address Generator - Full Pipeline
# This script automates the entire vanity address generation process

set -e

echo "🐉 Dragon Vanity Address Generator"
echo "=================================="
echo ""

# Step 1: Get bytecode hash
echo "📋 Step 1: Getting bytecode hash..."
echo "Running: npx hardhat run script/GetDragonBytecodeHash.s.sol"

BYTECODE_OUTPUT=$(npx hardhat run script/GetDragonBytecodeHash.s.sol)
echo "Hardhat output received"

# Extract bytecode hash (try multiple patterns)
BYTECODE_HASH=$(echo "$BYTECODE_OUTPUT" | grep -o '0x[a-fA-F0-9]\{64\}' | head -1)

if [ -z "$BYTECODE_HASH" ]; then
    echo "❌ Failed to extract bytecode hash from output"
    echo "Raw output:"
    echo "$BYTECODE_OUTPUT"
    echo ""
    echo "Please run manually:"
    echo "npx hardhat run script/GetDragonBytecodeHash.s.sol"
    echo "And copy the bytecode hash to run the generator manually"
    exit 1
fi

echo "✅ Bytecode hash: $BYTECODE_HASH"
echo ""

# Step 2: Check if Rust project exists
if [ ! -d "vanity-generator" ]; then
    echo "❌ vanity-generator directory not found"
    echo "Make sure you're in the project root"
    exit 1
fi

# Step 3: Build Rust generator (if needed)
echo "🔨 Step 2: Building Rust vanity generator..."
cd vanity-generator

if [ ! -f "target/release/generate_dragon_vanity" ]; then
    echo "Building optimized release binary..."
    cargo build --release --quiet
fi

echo "✅ Rust generator ready"
echo ""

# Step 4: Generate vanity address
echo "⚡ Step 3: Generating vanity address (0x69...7777)..."
echo "This may take a few minutes depending on your CPU..."
echo ""

GENERATOR_OUTPUT=$(cargo run --release --quiet -- \
    --factory 0xAA28020DDA6b954D16208eccF873D79AC6533833 \
    --bytecode-hash $BYTECODE_HASH \
    --starts-with 69 \
    --ends-with 7777 2>&1)

echo "$GENERATOR_OUTPUT"

# Extract salt and address from output
VANITY_SALT=$(echo "$GENERATOR_OUTPUT" | grep "Salt:" | grep -o '0x[a-fA-F0-9]\{64\}')
VANITY_ADDRESS=$(echo "$GENERATOR_OUTPUT" | grep "Address:" | grep -o '0x[a-fA-F0-9]\{40\}')

if [ -z "$VANITY_SALT" ] || [ -z "$VANITY_ADDRESS" ]; then
    echo ""
    echo "❌ Vanity generation failed or was interrupted"
    echo "You can run the generator manually:"
    echo "cd vanity-generator"
    echo "cargo run --release -- --bytecode-hash $BYTECODE_HASH --starts-with 69 --ends-with 7777"
    exit 1
fi

echo ""
echo "🎉 SUCCESS! Vanity address generated!"
echo "====================================="
echo "Salt: $VANITY_SALT"
echo "Address: $VANITY_ADDRESS"
echo ""

# Step 5: Update deployment script
cd ..
echo "📝 Step 4: Updating deployment script..."

# Backup original file
cp script/DeployVanityOmniDragon.s.sol script/DeployVanityOmniDragon.s.sol.backup

# Update the constants
sed -i.tmp "s/bytes32 constant VANITY_SALT = 0x[a-fA-F0-9]*;/bytes32 constant VANITY_SALT = $VANITY_SALT;/" script/DeployVanityOmniDragon.s.sol
sed -i.tmp "s/address constant EXPECTED_ADDRESS = 0x[a-fA-F0-9]*;/address constant EXPECTED_ADDRESS = $VANITY_ADDRESS;/" script/DeployVanityOmniDragon.s.sol

# Clean up temp files
rm -f script/DeployVanityOmniDragon.s.sol.tmp

echo "✅ Deployment script updated"
echo ""

# Step 6: Show deployment commands
echo "🚀 Step 5: Ready to deploy!"
echo "=========================="
echo ""
echo "Your omniDRAGON token will be deployed at:"
echo "$VANITY_ADDRESS"
echo ""
echo "Deploy commands:"
echo "1. Sonic (6,942,000 initial supply):"
echo "   npx hardhat run script/DeployVanityOmniDragon.s.sol --network sonic"
echo ""
echo "2. Other chains (zero initial supply):"
echo "   npx hardhat run script/DeployVanityOmniDragon.s.sol --network arbitrum"
echo "   npx hardhat run script/DeployVanityOmniDragon.s.sol --network ethereum"
echo "   npx hardhat run script/DeployVanityOmniDragon.s.sol --network base"
echo "   npx hardhat run script/DeployVanityOmniDragon.s.sol --network avalanche"
echo ""
echo "3. Configure LayerZero peers after all deployments"
echo ""
echo "💎 Features of your vanity omniDRAGON:"
echo "- ✅ Same address on all chains: $VANITY_ADDRESS"
echo "- ✅ Vanity pattern: 0x69...7777"
echo "- ✅ 6,942,000 DRAGON initial supply on Sonic"
echo "- ✅ LayerZero V2 OFT for cross-chain transfers"
echo "- ✅ Smart fee detection and lottery integration"
echo "- ✅ Ready for your VRF system integration"
echo ""
echo "🎯 Your cross-chain DRAGON ecosystem is ready to launch!"
