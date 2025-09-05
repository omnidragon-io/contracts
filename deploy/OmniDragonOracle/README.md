# OmniDragon Cross-Chain Oracle Infrastructure

> **Multi-chain price oracle ecosystem powered by LayerZero for the OmniDragon protocol**

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-363636?style=flat-square&logo=solidity)](https://soliditylang.org/)
[![LayerZero](https://img.shields.io/badge/LayerZero%20V2-lzRead-6366f1?style=flat-square)](https://layerzero.network/)
[![Cross-Chain](https://img.shields.io/badge/Cross--Chain-Oracle-22c55e?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](https://opensource.org/licenses/MIT)

## Overview

The OmniDragon Oracle Infrastructure provides **real-time cross-chain price feeds** for the DRAGON token across multiple blockchains. Built on **LayerZero V2**, it enables seamless price synchronization between chains with multiple oracle feed integrations.

### Key Features
- **Cross-Chain Compatibility**: Sonic ↔ Arbitrum via LayerZero Read
- **Multi-Oracle Aggregation**: Chainlink, Pyth, Band, API3 integration
- **Real-Time Updates**: Sub-second price synchronization
- **Fail-Safe Design**: Graceful degradation and redundancy
- **LayerZero Read Compatible**: Fixed `_lzReceive` message handling
- **Frontend Ready**: Exposed individual oracle feeds for dApps

## Architecture

```
┌─────────────────┐    LayerZero Read    ┌─────────────────┐
│   ARBITRUM      │◄────────────────────►│     SONIC       │
│                 │                      │                 │
│ OmniDragonOracle│                      │ OmniDragonOracle│
│   (SECONDARY)   │                      │   (PRIMARY)     │
│                 │                      │                 │
│ ┌─────────────┐ │                      │ ┌─────────────┐ │
│ │Request Price│ │                      │ │Price Feeds  │ │
│ └─────────────┘ │                      │ │• Chainlink  │ │
└─────────────────┘                      │ │• Pyth       │ │
                                         │ │• Band       │ │
                                         │ │• API3       │ │
                                         │ │• DEX TWAP   │ │
                                         │ └─────────────┘ │
                                         └─────────────────┘
```

## Quick Start

### Prerequisites
```bash
# Install dependencies
npm install
forge install

# Set up environment
cp .env.example .env
# Configure your RPC URLs and private keys
```

### Deploy & Configure
```bash
# Complete deployment guide
cd deploy/OmniDragonOracle/
cat DEPLOY.md
```

## Project Structure

```
layerzero-cli-workspace/
├── contracts/
│   └── core/oracles/
│       └── OmniDragonOracle.sol          # Main oracle contract
├── deploy/
│   └── OmniDragonOracle/                 # Complete deployment toolkit
│       ├── README.md                     # Project overview
│       ├── DEPLOY.md                     # Deployment guide
│       ├── DeployVanityOracleViaCreate2.s.sol
│       ├── layerzero-oracle-read.config.ts
│       └── oracle-vanity-generator/      # Vanity address tools
├── deployments/                          # Contract deployments
├── test/                                 # Test suites  
└── Configuration files
    ├── hardhat.config.ts                # Unified config
    ├── foundry.toml                     # Forge settings
    └── layerzero-omnidragon.config.ts   # LZ configuration
```

## Core Components

### OmniDragonOracle.sol
The heart of the system - a sophisticated price oracle that:
- **Aggregates** multiple oracle feeds with fail-safes
- **Provides** LayerZero Read compatible price queries
- **Maintains** TWAP calculations from DEX pairs  
- **Exposes** individual feed data for frontend integration

```solidity
// Get aggregated price (LayerZero Read compatible)
function getLatestPrice() external view returns (int256 price, uint256 timestamp)

// Get individual oracle feeds
function getChainlinkPrice() external view returns (int256 price, uint256 timestamp)
function getPythPrice() external view returns (int256 price, uint256 timestamp)
function getBandPrice() external view returns (int256 price, uint256 timestamp)
function getAPI3Price() external view returns (int256 price, uint256 timestamp)
function getAllOraclePrices() external view returns (
    int256 chainlinkPrice, bool chainlinkValid,
    int256 pythPrice, bool pythValid,
    int256 bandPrice, bool bandValid, 
    int256 api3Price, bool api3Valid
)

// Cross-chain functions
function requestPrice(uint32 targetEid, bytes calldata options) external payable
function setPeer(uint32 eid, bytes32 peer) external
function setMode(uint8 mode) external
```

### Cross-Chain Communication
- **Primary Oracle** (Sonic): Aggregates all price feeds
- **Secondary Oracle** (Arbitrum): Requests prices via LayerZero Read
- **Peer Configuration**: Automatic peer discovery and mapping

## Oracle Feeds

| **Feed** | **Network** | **Update Frequency** | **Reliability** |
|----------|-------------|---------------------|-----------------|
| Chainlink | Multiple | ~1 minute | 🟢 High |
| Pyth | Multiple | ~1 second | 🟢 High |
| Band | Multiple | ~5 minutes | 🟡 Medium |
| API3 | Multiple | ~2 minutes | 🟡 Medium |
| DEX TWAP | Sonic | Real-time | 🟢 High |

## Deployment Status

### Current Deployments
- **Sonic Oracle**: `0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777` (PRIMARY)
- **Arbitrum Oracle**: `0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777` (SECONDARY)

> ✅ **Status**: Fully operational with working LayerZero cross-chain communication

### Network Configuration
```typescript
// LayerZero Endpoint IDs
SONIC_EID: 30332
ARBITRUM_EID: 30110

// Oracle Modes
PRIMARY: Aggregates and provides prices
SECONDARY: Requests prices from PRIMARY via LayerZero Read
```

## Development

### Testing
```bash
# Run oracle price checks
cd deploy/OmniDragonOracle/
forge script CheckOraclePrice.s.sol --rpc-url $SONIC_RPC

# Test cross-chain communication
npx hardhat lz:oapp-read:wire --oapp-config layerzero-oracle-read.config.ts
```

### Local Development
```bash
# Start local nodes
anvil --fork-url $SONIC_RPC
anvil --fork-url $ARBITRUM_RPC

# Deploy locally
forge script DeployVanityOracleViaCreate2.s.sol --broadcast
```

## Frontend Integration

### Price Feed Access
```javascript
// Get aggregated price
const [price, timestamp] = await oracle.getLatestPrice();

// Get individual feeds for comparison
const chainlinkPrice = await oracle.getChainlinkPrice();
const pythPrice = await oracle.getPythPrice();

// Get all feeds at once
const allPrices = await oracle.getAllOraclePrices();
```

### Real-Time Updates
```javascript
// Listen for price updates
oracle.on('PriceUpdated', (newPrice, timestamp) => {
    console.log(`DRAGON price: ${newPrice} at ${timestamp}`);
});

// Cross-chain price request from Arbitrum
const tx = await oracle.requestPrice(30332, "0x", { 
    value: ethers.parseEther("0.000034") 
});

// Listen for cross-chain responses
oracle.on('CrossChainPriceReceived', (targetEid, dragonPrice, nativePrice, timestamp) => {
    console.log(`Received price from chain ${targetEid}: $${dragonPrice}`);
});
```

## Security

- **Multi-Signature**: Critical functions require multi-sig approval
- **Oracle Redundancy**: Multiple independent price feeds
- **Graceful Degradation**: System continues with partial feeds
- **LayerZero Security**: Leverages LZ's battle-tested infrastructure
- **Fixed LayerZero Read**: `getLatestPrice()` returns graceful values instead of reverting

## Recent Updates

### ✅ LayerZero Read Compatibility Fix (Latest)
- **Fixed**: `_lzReceive` message format mismatch that caused execution reverts
- **Fixed**: `getLatestPrice()` now returns graceful `(0,0)` instead of reverting  
- **Result**: Cross-chain price requests now work flawlessly
- **Status**: Fully operational cross-chain oracle system

### Configuration
- **Oracle Addresses**: All using vanity address `0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777`
- **Price Feeds**: 4 oracles configured with `setPullOracle` function
- **LP Pair**: DRAGON/S pair properly configured with `setPair`
- **TWAP**: Enabled for time-weighted average pricing

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## API Reference

### Price Functions
| Function | Description | Returns |
|----------|-------------|---------|
| `getLatestPrice()` | Get aggregated DRAGON price | `(int256 price, uint256 timestamp)` |
| `getAllOraclePrices()` | Get all individual feed prices | Multiple price/validity pairs |
| `getChainlinkPrice()` | Get Chainlink feed only | `(int256 price, uint256 timestamp)` |
| `getPythPrice()` | Get Pyth feed only | `(int256 price, uint256 timestamp)` |

### Cross-Chain Functions  
| Function | Description | Gas Required |
|----------|-------------|--------------|
| `requestPrice(uint32, bytes)` | Request price from another chain | ~0.000034 ETH |
| `setPeer(uint32, bytes32)` | Configure LayerZero peer | Admin only |
| `setMode(uint8)` | Set PRIMARY/SECONDARY mode | Admin only |

### Events
```solidity
event PriceUpdated(int256 newPrice, uint256 timestamp);
event CrossChainPriceReceived(uint32 targetEid, int256 dragonPrice, int256 nativePrice, uint256 timestamp);
event PeerSet(uint32 eid, bytes32 peer);
```

## Performance & Costs

### Gas Costs
- **Cross-chain request**: ~0.000034 ETH on Arbitrum
- **Price update**: ~50,000 gas on Sonic  
- **Oracle configuration**: ~25,000 gas per oracle

### Latency
- **Local price query**: <100ms
- **Cross-chain request**: 2-5 minutes (LayerZero confirmation time)
- **Price feed updates**: Real-time to 5 minutes (varies by oracle)

## Troubleshooting

### Common Issues
1. **"Price too stale"**: Check if oracle feeds are updating properly
2. **Cross-chain request fails**: Verify sufficient gas payment and peer configuration
3. **Oracle returns (0,0)**: Price feeds may be inactive or oracle not initialized

### Health Check
```javascript
// Check if oracle is healthy
const [price, timestamp] = await oracle.getLatestPrice();
const isHealthy = price > 0 && timestamp > (Date.now()/1000 - 3600); // 1 hour tolerance
```

## Support

- **Documentation**: Complete deployment guide in `DEPLOY.md`
- **Issues**: Open an issue for bugs or feature requests  
- **Discussions**: Join community discussions for questions

---

**Built for the OmniDragon ecosystem**
