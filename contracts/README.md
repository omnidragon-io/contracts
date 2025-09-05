# OmniDragon Smart Contracts

This directory contains the complete smart contract architecture for the OmniDragon ecosystem - a comprehensive cross-chain DeFi protocol built on LayerZero V2.

## Contract Architecture Overview

```
contracts/
├── core/                          # Core protocol contracts
│   ├── config/                   # Configuration and registry contracts
│   │   ├── OmniDragonRegistry.sol    # Central registry for all contracts
│   │   └── CREATE2FactoryWithOwnership.sol # Factory for deterministic deployments
│   ├── 🚧 governance/               # Governance and voting system
│   │   ├── GaugeController.sol    # Gauge voting controller
│   │   ├── partners/                 # Partner reward contracts
│   │   └── voting/                   # veDRAGON voting mechanics
│   ├── lottery/                  # Lottery and jackpot system
│   │   ├── OmniDragonLotteryManager.sol # Main lottery controller
│   │   └── DragonJackpotVault.sol    # Jackpot vault and distribution
│   ├── oracles/                  # Oracle infrastructure
│   │   └── OmniDragonOracle.sol     # Cross-chain oracle with LayerZero
│   ├── tokens/                   # Token contracts
│   │   ├── omniDRAGON.sol           # Main OFT token with fees
│   │   ├── 🚧 redDRAGON.sol            # UniV2 DRAGON LP in ERC-4626
│   │   └── 🚧 veDRAGON.sol             # Vote-escrowed governance token
│   └── vrf/                      # Cross-chain randomness
│       ├── ChainlinkVRFIntegratorV2_5.sol # VRF request coordinator
│       └── OmniDragonVRFConsumerV2_5.sol  # VRF response handler
├── interfaces/                   # Contract interfaces
│   ├── config/                   # Configuration interfaces
│   ├── 🚧 governance/               # Governance interfaces
│   ├── lottery/                  # Lottery system interfaces
│   ├── oracles/                  # Oracle interfaces
│   ├── protocols/                # External protocol interfaces
│   ├── tokens/                   # Token interfaces
│   └── vrf/                      # VRF interfaces
└── libraries/                   # Utility libraries
    ├── core/                     # Core utilities
    ├── errors/                   # Custom error definitions
    ├── fees/                     # Fee management libraries
    ├── math/                     # Mathematical calculations
    └── security/                 # Security utilities
```

## Core Components

### Token System (`core/tokens/`)

#### omniDRAGON.sol
- **Type**: LayerZero V2 OFT (Omnichain Fungible Token)
- **Features**:
  - Cross-chain transfers across 6+ chains
  - Smart fee detection (10% on DEX trades, 0% on liquidity/bridging)
  - Built-in lottery integration
  - Immediate fee distribution (no accumulation)
- **Address**: `0x69dc1c36f8b26db3471acf0a6469d815e9a27777` (same on all chains)

#### redDRAGON.sol 🚧
- **Type**: ERC-4626 Omnichain vault token of UniV2 DRAGON LP
- **Purpose**: Revenue distribution and yield farming
- **Features**: Auto-compounding rewards, fee collection
- **Status**: Under construction

#### veDRAGON.sol 🚧
- **Type**: Vote-escrowed token
- **Purpose**: Governance and voting power
- **Features**: Lock redDRAGON for voting power, time-weighted voting
- **Status**: Under construction

> **🔍 AUDIT READY**: All contracts except the above three (redDRAGON.sol, veDRAGON.sol, GaugeController.sol) are ready for smart contract audit.

### Lottery System (`core/lottery/`)

#### OmniDragonLotteryManager.sol
- **Purpose**: Main lottery controller and jackpot management
- **Features**:
  - Cross-chain jackpot pools
  - VRF-powered fair randomness
  - Instantaneous lottery jackpot Swap-to-Win
- **Integration**: Works with Chainlink VRF v2.5 via LayerZero

#### DragonJackpotVault.sol
- **Purpose**: Jackpot fund management and distribution
- **Features**:
  - Secure prize pool storage
  - Automated winner selection

### VRF System (`core/vrf/`)

#### ChainlinkVRFIntegratorV2_5.sol
- **Purpose**: Cross-chain VRF request coordinator
- **Features**:
  - LayerZero messaging for cross-chain randomness
  - Chainlink VRF v2.5 integration (Arbitrum)
  - Fee optimization and gas management

#### OmniDragonVRFConsumerV2_5.sol
- **Purpose**: VRF response handler and callback receiver
- **Features**:
  - Processes random numbers from Chainlink
  - Triggers lottery draws and other random events
  - Cross-chain callback handling

### Oracle Infrastructure (`core/oracles/`)

#### OmniDragonOracle.sol
- **Purpose**: Cross-chain price feeds and data aggregation via lzRead
- **Features**:
  - LayerZero-powered cross-chain data
  - Multiple oracle source integration (API3, Pyth, Chainlink)
  - Decentralized price feeds
  - Cross-chain message verification

### Governance System (`core/governance/`)

#### GaugeController.sol 🚧
- **Purpose**: veDRAGON-weighted voting for protocol parameters
- **Features**:
  - Time-weighted voting power
  - Gauge-based reward distribution
  - Cross-chain governance signals
- **Status**: Under construction

### Configuration (`core/config/`)

#### OmniDragonRegistry.sol
- **Purpose**: Central contract registry and configuration
- **Features**:
  - Contract address management
  - Protocol parameter storage
  - Access control and permissions

## Interfaces (`interfaces/`)

Organized by functional area:
- **config/**: Registry and configuration interfaces
- **governance/**: Voting and governance interfaces
- **lottery/**: Lottery system interfaces
- **oracles/**: Oracle and price feed interfaces
- **protocols/**: External protocol integrations
- **tokens/**: Token contract interfaces
- **vrf/**: Randomness system interfaces

## Libraries (`libraries/`)

### Core Utilities (`libraries/core/`)
- Date/time manipulation functions
- Common protocol utilities

### Error Handling (`libraries/errors/`)
- Gas-efficient custom error definitions
- Standardized error messages across contracts

### Fee Management (`libraries/fees/`)
- Fee calculation algorithms
- Distribution mechanics
- Yield optimization strategies

### Mathematics (`libraries/math/`)
- Precision math for DeFi calculations
- veDRAGON voting power calculations
- Fee distribution algorithms

### Security (`libraries/security/`)
- Reentrancy protection
- Access control utilities
- Safe math operations

## Cross-Chain Architecture

The OmniDragon ecosystem leverages LayerZero V2 for seamless cross-chain functionality:

### Supported Chains
- **Ethereum** (EID: 30101)
- **Arbitrum** (EID: 30110)
- **Base** (EID: 30184)
- **Avalanche** (EID: 30106)
- **Sonic** (EID: 30332)
- **BSC** (EID: 30102) - Planned

### Key Cross-Chain Features
1. **Omnichain Tokens**: DRAGON transfers across all supported chains
2. **Cross-Chain VRF**: Decentralized randomness across chains
3. **Unified Liquidity**: Single contract addresses across chains
4. **Cross-Chain Governance**: veDRAGON voting with multi-chain signals

## Development Guidelines

### Contract Standards
- **Solidity**: ^0.8.20 (latest stable)
- **LayerZero**: V2 protocol for cross-chain messaging
- **OpenZeppelin**: Latest contracts library
- **Chainlink**: VRF v2.5 for randomness

### Security Considerations
- All contracts use `ReentrancyGuard`
- Custom error definitions for gas efficiency
- Multi-sig governance for critical functions
- Comprehensive test coverage required

### Testing
```bash
# Run all contract tests
forge test

# Run specific test suite
forge test --match-path test/OmniDragon*

# Test cross-chain functionality
forge test --match-path test/CrossChain*
```

### Deployment
```bash
# Deploy to specific network
npx hardhat run scripts/deploy.ts --network sonic

# Verify contracts
npx hardhat verify --network sonic <CONTRACT_ADDRESS>
```

## Contract Dependencies

### External Libraries
- **@openzeppelin/contracts**: Access control, token standards, security
- **@layerzerolabs/lz-evm-oapp-v2**: Cross-chain messaging
- **@chainlink/contracts**: VRF randomness
- **solmate**: Gas-efficient implementations

### Internal Dependencies
- Contracts use relative imports within the ecosystem
- Interfaces define clear contract boundaries
- Libraries provide shared functionality

## Maintenance

### Adding New Contracts
1. Create contract in appropriate `core/` subdirectory
2. Define interface in `interfaces/` directory
3. Add contract to registry if needed
4. Update deployment scripts
5. Add comprehensive tests

### Updating Existing Contracts
1. Create new version with incremented contract name
2. Update interfaces if ABI changes
3. Test cross-contract interactions
4. Update deployment configurations
5. Migrate state if necessary

---

0xakita.eth

