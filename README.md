# OmniDragon Ecosystem

A comprehensive cross-chain DeFi ecosystem built on LayerZero V2, featuring omnichain tokens, decentralized randomness, lottery systems, and oracle infrastructure.

## Overview

OmniDragon is a multi-chain DeFi protocol that leverages LayerZero's omnichain messaging to create seamless cross-chain experiences. The ecosystem includes:

- **OmniDRAGON**: Omnichain Fungible Token (OFT) deployed across 6+ chains
- **Cross-Chain VRF**: Decentralized randomness using Chainlink VRF v2.5
- **Lottery System**: Cross-chain jackpot and lottery functionality
- **Oracle Infrastructure**: Price feeds and data aggregation
- **Governance**: veDRAGON voting and revenue distribution
- **Bridge Integration**: Seamless token transfers across chains

## Quick Start

### Prerequisites
- Node.js 18+
- Foundry (for smart contracts)
- pnpm or npm

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd layerzero-cli-workspace

# Install dependencies
pnpm install
forge install

# Setup environment
cp .env.example .env
# Configure your RPC URLs and private keys
```

### Deploy Contracts
```bash
# Deploy OmniDRAGON token
cd deploy/OmniDragonOFT/
npx hardhat run scripts/deploy.ts --network sonic

# Deploy VRF system
cd deploy/OmniDragonVRF/
npx hardhat run scripts/deploy-vrf.ts --network sonic
```

## Project Structure

```
├── contracts/                 # Smart contracts
│   ├── core/
│   │   ├── tokens/           # OmniDRAGON OFT token
│   │   ├── lottery/          # Lottery manager contracts
│   │   ├── oracles/          # Oracle infrastructure
│   │   ├── vrf/             # Cross-chain VRF system
│   │   └── governance/      # veDRAGON governance
│   └── interfaces/          # Contract interfaces
├── deploy/                   # Deployment scripts and configs
├── test/                     # Test suites
├── deployments/              # Deployment records and addresses
├── docs/                     # Documentation
└── scripts/                  # Utility scripts
```

## Core Components

### OmniDRAGON Token (OFT)
- **Symbol**: DRAGON
- **Standard**: ERC-20 + LayerZero V2 OFT
- **Address**: `0x69dc1c36f8b26db3471acf0a6469d815e9a27777` (same on all chains)
- **Chains**: Ethereum, Arbitrum, Base, Avalanche, Sonic, BSC

### Cross-Chain VRF System
- **Technology**: Chainlink VRF v2.5 + LayerZero V2
- **Coordinator**: `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e` (Arbitrum)
- **Supported Chains**: Sonic, Arbitrum, Ethereum, BSC, Avalanche

### Lottery System
- **Contract**: OmniDragonLotteryManager
- **Features**: Cross-chain jackpot pools, automated draws
- **Integration**: VRF-powered randomness for fair draws

## Supported Chains

| Chain | EID | Status | Explorer |
|-------|-----|--------|----------|
| Ethereum | 30101 | Deployed | [Etherscan](https://etherscan.io) |
| Arbitrum | 30110 | Deployed | [Arbiscan](https://arbiscan.io) |
| Base | 30184 | Deployed | [BaseScan](https://basescan.org) |
| Avalanche | 30106 | Deployed | [SnowScan](https://snowscan.xyz) |
| Sonic | 30332 | Deployed | [SonicScan](https://sonicscan.org) |
| BSC | 30102 | Planned | [BscScan](https://bscscan.com) |

## Development

### Testing
```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/OmniDragonOFT.t.sol

# Run with gas reporting
forge test --gas-report
```

### Deployment
```bash
# Deploy to specific network
npx hardhat run scripts/deploy.ts --network arbitrum

# Verify contracts
npx hardhat verify --network arbitrum <CONTRACT_ADDRESS>
```

### Cross-Chain Testing
```bash
# Test VRF system health
npx hardhat run scripts/test-vrf-system.ts --network sonic

# Test token bridging
npx hardhat run scripts/test-oft-bridge.ts --network sonic
```

## Documentation

- [**Deployment Guide**](./docs/DEPLOYMENT.md) - Complete deployment instructions
- [**Frontend Integration**](./docs/FRONTEND_INTEGRATION.md) - Bridge and token integration
- [**VRF System**](./deployments/README.md) - Cross-chain randomness documentation
- [**Oracle Deployment**](./docs/OMNIDRAGON_ORACLE_DEPLOYMENT_SUMMARY.md) - Oracle infrastructure

## Key Scripts

### Token Operations
```bash
# Bridge tokens cross-chain
cast send <TOKEN_ADDRESS> \
  "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)" \
  "(<DST_EID>,<TO_B32>,<AMOUNT>,<AMOUNT>,0x,0x,0x)" "(<NATIVE_FEE>,0)" <TO> \
  --value <NATIVE_FEE> \
  --rpc-url $RPC_URL
```

### VRF Requests
```bash
# Get VRF quote
npx hardhat run scripts/vrf-helper.ts --network sonic

# Request randomness
cast send 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5 \
  "requestRandomWordsSimple(uint32)" 30110 \
  --value 0.21ether \
  --rpc-url $RPC_URL_SONIC
```

## Security

- All contracts are verified on respective block explorers
- Multi-sig governance for critical operations
- Comprehensive test coverage
- Audited smart contracts (when applicable)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## About OmniDragon

OmniDragon is building the future of cross-chain DeFi by leveraging LayerZero's omnichain messaging to create seamless, secure, and efficient cross-chain experiences. Our ecosystem includes tokens, randomness, lotteries, and governance systems that work together to provide users with powerful DeFi tools across multiple blockchains.

### Key Features
- **Cross-Chain Compatibility**: Seamless transfers across 6+ chains
- **Decentralized Randomness**: Chainlink VRF integration
- **Fair Lotteries**: VRF-powered jackpot systems
- **Community Governance**: veDRAGON voting system
- **Oracle Infrastructure**: Reliable price feeds

---

**Built by the OmniDragon team**

*For questions or support, join our [Discord](https://discord.gg/omnidragon), visit our [documentation](https://docs.omnidragon.io), or create an issue on GitHub.*
