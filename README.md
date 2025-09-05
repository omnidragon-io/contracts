# LayerZero CLI Workspace

Development environment for OmniDragon cross-chain oracle infrastructure.

## Quick Navigation

- **📖 Documentation**: [`deploy/OmniDragonOracle/README.md`](deploy/OmniDragonOracle/README.md)
- **🚀 Deployment Guide**: [`deploy/OmniDragonOracle/DEPLOY.md`](deploy/OmniDragonOracle/DEPLOY.md)
- **⚙️ Oracle Contract**: [`contracts/core/oracles/OmniDragonOracle.sol`](contracts/core/oracles/OmniDragonOracle.sol)

## Project Structure

```
├── contracts/                   # Smart contracts
├── deploy/OmniDragonOracle/    # Complete deployment toolkit
├── test/                       # Test suites
├── deployments/                # Deployment records
└── Configuration files
```

## Getting Started

```bash
# Install dependencies
npm install
forge install

# Configure environment
cp .env.example .env

# Deploy oracle
cd deploy/OmniDragonOracle/
cat DEPLOY.md
```

## Technologies

- **Solidity** ^0.8.20
- **LayerZero V2** (Cross-chain messaging)
- **Foundry** (Smart contract framework)
- **Hardhat** (Development environment)

---

For complete documentation, see [`deploy/OmniDragonOracle/README.md`](deploy/OmniDragonOracle/README.md)
