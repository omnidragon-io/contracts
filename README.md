# OmniDragon Ecosystem

A cross-chain DeFi protocol built on LayerZero V2 with omnichain tokens, VRF randomness, lottery systems, and oracle infrastructure.

## 🚀 Quick Start

**Prerequisites:** Node.js 18+, Foundry, pnpm/npm

```bash
git clone <repository-url>
cd omnidragon-core
pnpm install && forge install
cp .env.example .env
```

📚 **Documentation**: [docs.omnidragon.io](https://docs.omnidragon.io)

## 🏗️ Architecture

**Core Components:**
- **OmniDRAGON**: ERC-20 OFT token across 6+ chains
- **VRF System**: Chainlink V2.5 + LayerZero randomness
- **Lottery**: Cross-chain jackpot pools with VRF fairness
- **Oracles**: Multi-source price feeds via LayerZero
- **Governance**: veDRAGON voting system

**Supported Chains:**
- Ethereum, Arbitrum, Base, Avalanche, Sonic
- BSC (planned)

📚 **Technical Details**: [docs.omnidragon.io](https://docs.omnidragon.io)

## 🛠️ Development

**Testing:**
```bash
forge test                    # Run all tests
forge test --gas-report      # With gas reporting
```

**Deployment:**
```bash
npx hardhat run scripts/deploy.ts --network <chain>
npx hardhat verify --network <chain> <CONTRACT_ADDRESS>
```

## 📚 Resources

**Documentation:** [docs.omnidragon.io](https://docs.omnidragon.io)

**Local Docs:**
- Deployment Guide, Frontend Integration
- VRF System, Oracle Infrastructure

**Scripts:** Token operations and VRF requests available in `/scripts/`

## 🛡️ Security & Contributing

**Security:** Verified contracts, multi-sig governance, comprehensive testing

**Contributing:** Fork → Branch → Test → PR

**License:** MIT

---

**Built by the OmniDragon team** 🐉

**Support:** [Discord](https://discord.gg/omnidragon) | [Docs](https://docs.omnidragon.io) | [GitHub Issues](https://github.com/omnidragon-io/omnifan/issues)
