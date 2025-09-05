# 🚀 Deploy Fixed OmniDragonOracle - Complete Guide

> ✅ **Latest Status**: Successfully deployed with working LayerZero cross-chain communication!  
> 🎯 **Current Address**: `0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777` on both Sonic and Arbitrum

## Prerequisites
- **Working Directory**: Ensure you're in `deploy/OmniDragonOracle/`
- **Private Key**: Configure your environment variables
- **CREATE2 Factory**: `0xAA28020DDA6b954D16208eccF873D79AC6533833`

> **Note**: All commands assume you're running from the `deploy/OmniDragonOracle/` directory

## Quick Setup
```bash
# Navigate to the deployment directory
cd deploy/OmniDragonOracle/

# Verify you have all required files
ls -la
# Should see: DeployVanityOracleViaCreate2.s.sol, GetInitBytecodeHash.s.sol, 
#             layerzero-oracle-read.config.ts, oracle-vanity-generator/
```

---

## Phase 1: Generate Vanity Address

### Step 1: Generate Init Bytecode Hash
```bash
echo "📋 Step 1: Generate init bytecode hash..."
forge script GetInitBytecodeHash.s.sol --rpc-url https://rpc.soniclabs.com/ -vv
```

### Step 2: Generate Vanity Salt (Rust)
```bash
echo "🎲 Step 2: Generate vanity salt..."
cd oracle-vanity-generator/
cargo run -- --bytecode-hash YOUR_BYTECODE_HASH_HERE --prefix 69 --suffix 777
cd ..
```

### Step 3: Update Deployment Script
Update `DeployVanityOracleViaCreate2.s.sol`:
```solidity
bytes32 constant VANITY_SALT = 0xYOUR_NEW_SALT_HERE;
address constant EXPECTED_ADDRESS = 0x69XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX777;
```

---

## Phase 2: Deploy & Configure Sonic Oracle

### Step 4: Deploy to Sonic
```bash
echo "🚀 Step 4: Deploy to Sonic..."
forge script DeployVanityOracleViaCreate2.s.sol \
  --rpc-url https://rpc.soniclabs.com/ \
  --broadcast --private-key $PRIVATE_KEY -vv

export ORACLE_ADDRESS=0x69XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX777  # Update with actual address
```

### Step 5: Configure 4 Price Oracles (CORRECTED)
```bash
echo "🔧 Step 5: Configure price oracles with setPullOracle..."

# Chainlink (ID 0) - 25% weight, 1h staleness
cast send $ORACLE_ADDRESS \
  "setPullOracle(uint8,bool,uint8,uint32,address,string)" \
  0 true 25 3600 0xc76dFb89fF298145b417d221B2c747d84952e01d "S/USD" \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY

# Pyth (ID 1) - 25% weight, 1h staleness
cast send $ORACLE_ADDRESS \
  "setPullOracle(uint8,bool,uint8,uint32,address,string)" \
  1 true 25 3600 0x2880aB155794e7179c9eE2e38200202908C17B43 "S/USD" \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY

# Band (ID 2) - 25% weight, 1h staleness
cast send $ORACLE_ADDRESS \
  "setPullOracle(uint8,bool,uint8,uint32,address,string)" \
  2 true 25 3600 0x506085050Ea5494Fe4b89Dd5BEa659F506F470Cc "S/USD" \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY

# API3 (ID 3) - 25% weight, 1h staleness  
cast send $ORACLE_ADDRESS \
  "setPullOracle(uint8,bool,uint8,uint32,address,string)" \
  3 true 25 3600 0x726D2E87d73567ecA1b75C063Bd09c1493655918 "S/USD" \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY
```

> 🔧 **Note**: All oracles use `setPullOracle` with equal 25% weights and 1-hour staleness

### Step 6: Configure Dragon/wS LP Pair
```bash
echo "🔧 Step 6: Configure Dragon/wS LP pair..."
cast send $ORACLE_ADDRESS \
  "setPair(address,address,address)" \
  0x33503bc86f2808151a6e083e67d7d97a66dfec11 \
  0x69Dc1c36F8B26Db3471ACF0a6469D815E9A27777 \
  0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38 \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY
```

### Step 7: Enable TWAP
```bash
echo "🔧 Step 7: Enable TWAP..."
cast send $ORACLE_ADDRESS \
  "setTwapEnabled(bool)" true \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY
```

### Step 8: Set PRIMARY Mode & Initialize Price
```bash
echo "🔧 Step 8: Set PRIMARY mode..."
cast send $ORACLE_ADDRESS \
  "setMode(uint8)" 1 \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY

echo "🔧 Step 8b: Update price..."
cast send $ORACLE_ADDRESS \
  "updatePrice()" \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY
```

---

## Phase 3: Deploy & Configure Arbitrum Oracle

### Step 9: Deploy to Arbitrum
```bash
echo "🚀 Step 9: Deploy to Arbitrum..."
forge script DeployVanityOracleViaCreate2.s.sol \
  --rpc-url https://arb1.arbitrum.io/rpc \
  --broadcast --private-key $PRIVATE_KEY -vv
```

### Step 10: Set SECONDARY Mode
```bash
echo "🔧 Step 10: Set Arbitrum as SECONDARY..."
cast send $ORACLE_ADDRESS \
  "setMode(uint8)" 2 \
  --rpc-url https://arb1.arbitrum.io/rpc --private-key $PRIVATE_KEY
```

---

## Phase 4: Configure LayerZero Cross-Chain

### Step 11: Set Peer Connections
```bash
echo "🔗 Step 11: Set peer connections..."

# Set Arbitrum peer on Sonic (EID 30110)
cast send $ORACLE_ADDRESS \
  "setPeer(uint32,bytes32)" 30110 \
  0x0000000000000000000000069e93A95C8243129d24240846679243fe3908777 \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY

# Set Sonic peer on Arbitrum (EID 30332)  
cast send $ORACLE_ADDRESS \
  "setPeer(uint32,bytes32)" 30332 \
  0x0000000000000000000000069e93A95C8243129d24240846679243fe3908777 \
  --rpc-url https://arb1.arbitrum.io/rpc --private-key $PRIVATE_KEY

# Fix peer mappings if needed
cast send $ORACLE_ADDRESS \
  "emergencyFixPeerMapping(uint32)" 30110 \
  --rpc-url https://rpc.soniclabs.com/ --private-key $PRIVATE_KEY

cast send $ORACLE_ADDRESS \
  "emergencyFixPeerMapping(uint32)" 30332 \
  --rpc-url https://arb1.arbitrum.io/rpc --private-key $PRIVATE_KEY
```

### Step 12: Update LayerZero Config & Wire
```bash
echo "🔌 Step 12: Update config files..."

# Update layerzero-oracle-read.config.ts addresses to new vanity address
# Update .env ORACLE_ADDRESS to new vanity address

echo "🔌 Step 12b: Wire LayerZero configuration..."
npx hardhat lz:oapp-read:wire --oapp-config layerzero-oracle-read.config.ts
```

---

## Phase 5: Testing

### Step 13: Test Cross-Chain Price Request
```bash
echo "🧪 Step 13: Test cross-chain price request..."

# Test from Arbitrum to Sonic
cast send $ORACLE_ADDRESS \
  "requestPrice(uint32,bytes)" 30332 0x \
  --value 0.000034ether \
  --rpc-url https://arb1.arbitrum.io/rpc --private-key $PRIVATE_KEY
```

### Step 14: Verify Success
Check LayerZero Explorer for successful execution:
- ✅ Should see 4 log entries (including Sonic response)
- ✅ Should NOT see "UNRESOLVABLE_COMMAND"
- ✅ Should see proper hex response data

---

## 🎯 Key Variables

Replace these in the commands above:
- `$ORACLE_ADDRESS` = New vanity address (e.g., `0x69XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX777`)
- `$PRIVATE_KEY` = Your wallet private key
- `YOUR_BYTECODE_HASH_HERE` = Output from Step 1
- `0xYOUR_NEW_SALT_HERE` = Output from Step 2

## 🔧 Environment Variables Needed

```bash
export PRIVATE_KEY="your_private_key_here"
export ORACLE_ADDRESS=0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777  # Current working address
```



## 📋 Feed Addresses Reference

From `.env` file:
- **Chainlink**: `0xc76dFb89fF298145b417d221B2c747d84952e01d`
- **Band**: `0x506085050Ea5494Fe4b89Dd5BEa659F506F470Cc` 
- **API3**: `0x726D2E87d73567ecA1b75C063Bd09c1493655918`
- **Pyth**: `0x2880aB155794e7179c9eE2e38200202908C17B43`
- **Pyth Price ID**: `0xf490b178d0c85683b7a0f2388b40af2e6f7c90cbe0f96b31f315f08d0e5a2d6d`
- **Dragon Token**: `0x69Dc1c36F8B26Db3471ACF0a6469D815E9A27777`
- **Wrapped Sonic**: `0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38`
- **Dragon/wS LP**: `0x33503bc86f2808151a6e083e67d7d97a66dfec11`

## 🎯 Key Addresses

- **CREATE2 Factory**: `0xAA28020DDA6b954D16208eccF873D79AC6533833`
- **Sonic EID**: `30332`
- **Arbitrum EID**: `30110`
- **Target Vanity Pattern**: `0x69XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX777`

## 🎯 Expected Result

After completion, the oracle should:
- ✅ Generate proper LayerZero Read responses (no more "UNRESOLVABLE_COMMAND")
- ✅ Support cross-chain price requests from Arbitrum to Sonic
- ✅ Expose individual oracle prices for frontend display via:
  - `getChainlinkPrice()`
  - `getPythPrice()` 
  - `getBandPrice()`
  - `getAPI3Price()`
  - `getAllOraclePrices()`
- ✅ Return graceful values instead of reverting for LayerZero compatibility
- ✅ Use 24-hour staleness tolerance for LayerZero Read calls

## 🔧 Key Changes Made to Fix LayerZero Read

### 1. Fixed `getLatestPrice()` for Graceful Responses
**Before (Problematic):**
```solidity
function getLatestPrice() external view returns (int256 price, uint256 timestamp) {
    require(priceInitialized, "Price not initialized");
    require(latestPrice > 0, "Invalid price");
    require(block.timestamp <= lastUpdateTime + 3600, "Price too stale");
    return (latestPrice, lastUpdateTime);
}
```

**After (LayerZero Read Compatible):**
```solidity
function getLatestPrice() external view returns (int256 price, uint256 timestamp) {
    // LayerZero Read friendly - return graceful values instead of reverting
    if (!priceInitialized) {
        return (0, 0); // Not initialized yet
    }
    
    if (latestPrice <= 0) {
        return (0, 0); // Invalid price
    }
    
    // 24 hours staleness tolerance for LayerZero Read
    if (block.timestamp > lastUpdateTime + 86400) {
        return (0, 0); // Too stale
    }
    
    return (latestPrice, lastUpdateTime);
}
```

### 2. Fixed `_lzReceive()` Message Decoding
**Before (Problematic):**
```solidity
function _lzReceive(...) internal override {
    // Expected 6 parameters but LayerZero Read only sends 2
    (uint32 targetEid, int256 dragonPrice, uint256 dragonTs, 
     int256 nativePrice, bool nativeValid, uint256 nativeTs) 
        = abi.decode(_message, (uint32, int256, uint256, int256, bool, uint256));
}
```

**After (LayerZero Read Compatible):**
```solidity
function _lzReceive(Origin calldata _origin, ..., bytes calldata _message, ...) internal override {
    // LayerZero Read responses only contain (int256 price, uint256 timestamp)
    (int256 dragonPrice, uint256 dragonTs) = abi.decode(_message, (int256, uint256));
    uint32 targetEid = _origin.srcEid;
    // Handle gracefully with 0 for missing native price
    peerNativePrices[targetEid] = 0;
}
```

### Result
✅ **No more execution reverts**  
✅ **Cross-chain communication works flawlessly**  
✅ **LayerZero Read returns proper data instead of "UNRESOLVABLE_COMMAND"**

## 🎯 Current Working Configuration

- **Oracle Address**: `0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777`
- **Status**: ✅ Fully operational cross-chain oracle system
- **Last Test**: Successfully sent cross-chain price request and received response
