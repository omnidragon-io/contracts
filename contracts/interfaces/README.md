# Interface Organization

## Structure

The interfaces are organized into logical folders based on their purpose:

### `/dex`
DEX-related interfaces for interacting with decentralized exchanges.

- **IRouter.sol**: Unified router interface supporting multiple DEX protocols (Uniswap V2/V3, Algebra, Shadow Finance)

### `/lottery`
Lottery and jackpot system interfaces.

- **IDragonJackpotVault.sol**: Unified interface combining vault, distribution, and processor functionality
- **IOmniDragonLotteryManager.sol**: Interface for the lottery manager contract

### `/oracles`
Oracle-related interfaces for price feeds and cross-chain data.

- **IOmniDragonOracle.sol**: Unified oracle interface with LayerZero support
- **IApi3ReaderProxy.sol**: API3 oracle interface
- **IPyth.sol**: Pyth Network oracle interface
- **PythStructs.sol**: Pyth data structures

### `/protocols`
External protocol interfaces.

- **IPeapods.sol**: Interface for Peapods protocol (bonding and ERC-4626 vault)

### `/config`
Configuration and registry interfaces.

- **IOmniDragonRegistry.sol**: Central registry interface

### `/tokens`
Token-specific interfaces.

- **IOmniDRAGON.sol**: Interface for the omniDRAGON token
- **IveDRAGON.sol**: Interface for vote-escrowed DRAGON
- **IredDRAGON.sol**: Interface for redDRAGON
- **IWETH.sol**: Wrapped native token interface
