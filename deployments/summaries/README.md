# Deployment Summaries

## Overview

This directory contains structured deployment summaries for the OmniDragon ecosystem infrastructure.

## Summary Files

### 1. `multichain-deployments.json`
- **Purpose**: Tracks all multi-chain contract deployments
- **Key Info**: Registry addresses, chain IDs, deployment status
- **Networks**: Sonic, Arbitrum, Ethereum, Base, Avalanche, and more

### 2. `vrf-infrastructure.json`
- **Purpose**: Documents VRF (Verifiable Random Function) infrastructure
- **Key Components**:
  - Chainlink VRF v2.5 integration
  - LayerZero V2 cross-chain messaging
  - Network-specific deployments
  - Integration guides and security info

## File Structure

Each summary follows a hierarchical structure:

```json
{
  "deployment_info": {
    // General deployment metadata
  },
  "network_deployments": {
    // Per-network contract details
  },
  "configuration": {
    // System configuration
  },
  "operational_status": {
    // Current system status
  }
}
```

## Usage

### Reading Deployment Info
```bash
# Get all registry addresses
cat multichain-deployments.json | jq '.deployments.registry.networks'

# Get VRF integrator on Sonic
cat vrf-infrastructure.json | jq '.network_deployments.sonic.contracts.vrf_integrator'
```

### Checking Status
```bash
# Check VRF operational status
cat vrf-infrastructure.json | jq '.operational_status'

# Check deployment status
cat multichain-deployments.json | jq '.deployment_info.status'
```

## Naming Convention

- **Infrastructure Files**: `{component}-infrastructure.json`
  - Example: `vrf-infrastructure.json`
  
- **Deployment Files**: `{scope}-deployments.json`
  - Example: `multichain-deployments.json`

## Maintenance

1. **Updates**: When deploying new contracts, update relevant summary files
2. **Versioning**: Increment version numbers for major changes
3. **Status**: Keep operational status current
4. **Chain IDs**: Always include chain IDs for network clarity

## Key Addresses

### Common Addresses Across Networks
- **Owner**: `0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F`
- **CREATE2 Factory**: `0xAA28020DDA6b954D16208eccF873D79AC6533833`
- **Registry (All Networks)**: `0x6940aDc0A505108bC11CA28EefB7E3BAc7AF0777`

### VRF Infrastructure
- **Integrator (Sonic/Arbitrum)**: `0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5`
- **Consumer (Arbitrum)**: `0x697a9d438a5b61ea75aa823f98a85efb70fd23d5`
