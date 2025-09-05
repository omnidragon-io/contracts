# OmniDragon Ecosystem

A cross-chain DeFi protocol built on LayerZero V2 with omnichain tokens, VRF randomness, lottery systems, and oracle infrastructure.

## Quick Start

**Prerequisites:** Node.js 18+, Foundry, pnpm/npm

```bash
git clone <repository-url>
cd omnidragon-core
pnpm install && forge install
cp .env.example .env
```

## Architecture

**Core Components:**
- **OmniDRAGON**: ERC-20 OFT token across 6+ chains
- **VRF System**: Chainlink V2.5 + LayerZero randomness
- **Lottery**: Cross-chain jackpot pools with VRF fairness
- **Oracles**: Multi-source price feeds via LayerZero
- **Governance**: veDRAGON voting system

**Documentation:** [docs.omnidragon.io](https://docs.omnidragon.io)

## Security & Contributing

**Security:** Verified contracts, multi-sig governance, comprehensive testing

**Contributing:** Fork → Branch → Test → PR

**License:** MIT

---

**Built by the OmniDragon team**

**Support:** [Discord](https://discord.gg/omnidragon) | [Docs](https://docs.omnidragon.io) | [GitHub Issues](https://github.com/omnidragon-io/omnifan/issues)
