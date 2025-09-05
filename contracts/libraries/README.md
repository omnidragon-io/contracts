# Libraries Organization

## Structure

The libraries are organized into logical folders based on their purpose:

### `/core`
Core utility libraries for the Dragon ecosystem.
- **DragonDateTimeLib.sol**: Date/time utilities

### `/errors`
Custom error definitions for gas-efficient error handling.
- **DragonErrors.sol**: Common errors used across Dragon contracts
- **OracleErrors.sol**: Oracle-specific error definitions

### `/fees`
Fee management and distribution libraries.
- **DragonFeeManager.sol**: Unified fee calculation, distribution, and smart processing
- **OptimizedFeeMHelper.sol**: Complete FeeM integration with auto-claim and yield strategies

### `/helpers`
Helper contracts directory (currently being reorganized).
- **README.md**: Migration guide for moved helper contracts

### `/layerzero`
LayerZero protocol specific libraries.
- **LayerZeroOptionsHelper.sol**: Helper for creating proper LayerZero V2 message options

### `/math`
Mathematical libraries for calculations.
- **Math.sol**: General math utilities
- **veDRAGONMath.sol**: Vote-escrowed DRAGON math calculations

### `/security`
Security-related libraries.
- **ReentrancyGuard.sol**: Protection against reentrancy attacks

## Usage Guidelines

1. **Error Libraries**: Import from `/errors` for consistent error handling
2. **Helper Contracts**: Deploy separately, not meant to be inherited
3. **Math Libraries**: Use for complex calculations to ensure precision
4. **Security Libraries**: Always use for contracts handling value transfers
