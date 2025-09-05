# Dragon Fee Manager

## Overview

The `DragonFeeManager` library is a unified solution for all fee-related operations in the Dragon ecosystem. It combines the functionality of the previous `OmniDragonFeeLib` and `SmartFeeDistribution` libraries into a single, more powerful library.

## Features

### 1. Fee Calculation
- Calculate fee breakdowns based on configurable rates
- Support for different fee structures for buy/sell operations
- Optimal fee splitting between jackpot, veDRAGON, and burn

### 2. Smart Distribution
- Automatic detection of vault auto-processing capabilities
- Fallback to standard transfers if smart processing fails
- Batch distribution support

### 3. Token Conversion
- Convert tokens to native currency via DEX pairs
- Emergency token rescue functionality

## Usage Examples

### Basic Fee Calculation
```solidity
import {DragonFeeManager} from "./libraries/fees/DragonFeeManager.sol";

// Calculate fees
DragonFeeManager.Fees memory feeRates = DragonFeeManager.Fees({
    jackpot: 690,      // 6.9%
    veDRAGON: 241,     // 2.41%
    burn: 69,          // 0.69%
    total: 1000        // 10% total
});

DragonFeeManager.FeeAmounts memory amounts = DragonFeeManager.calculateFeeBreakdown(
    transferAmount,
    feeRates
);
```

### Smart Fee Distribution
```solidity
// Distribute fees with smart processing
DragonFeeManager.FeeDistributionParams memory params = DragonFeeManager.FeeDistributionParams({
    token: address(omniDRAGON),
    jackpotVault: jackpotAddress,
    veDragonContract: veDragonAddress,
    burnAddress: BURN_ADDRESS,
    amount: feeAmount,
    depositor: msg.sender,
    useSmartDistribution: true  // Enable smart distribution
});

DragonFeeManager.executeFeeDistribution(params);
```

### Direct Smart Distribution
```solidity
// Use smart distribution directly
DragonFeeManager.smartDistribute(
    address(omniDRAGON),
    jackpotVault,
    amount,
    depositor
);
```

### Batch Distribution
```solidity
address[] memory destinations = new address[](3);
destinations[0] = jackpotVault;
destinations[1] = veDragonVault;
destinations[2] = burnAddress;

uint256[] memory amounts = new uint256[](3);
amounts[0] = jackpotAmount;
amounts[1] = veDragonAmount;
amounts[2] = burnAmount;

DragonFeeManager.batchSmartDistribute(
    address(omniDRAGON),
    destinations,
    amounts,
    msg.sender
);
```
