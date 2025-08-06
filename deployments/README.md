# OmniDragon VRF Deployments

This folder contains deployment information for the OmniDragon cross-chain VRF system.

## 📋 Quick Reference

### Contract Addresses

| Contract | Network | Address |
|----------|---------|---------|
| ChainlinkVRFIntegratorV2_5 | Sonic | `0x4cc69C8FEd6d340742a347905ac99DdD5b2B0A90` |
| OmniDragonVRFConsumerV2_5 | Arbitrum | `0x4CC1b5e72b9a5A6D6cE2131b444bB483FA2815c8` |
| OmniDragonRegistry | Sonic | `0x69D485e1c69e2fB0B9Be0b800427c69D51d30777` |
| OmniDragonRegistry | Arbitrum | `0x69D485e1c69e2fB0B9Be0b800427c69D51d30777` |

### System Status: ✅ FULLY OPERATIONAL

## 📁 Folder Structure

```
deployments/
├── arbitrum/                      # Arbitrum deployments
│   ├── OmniDragonVRFConsumerV2_5.json
│   ├── OmniDragonRegistry.json
│   └── .chainId
├── sonic/                         # Sonic deployments  
│   ├── ChainlinkVRFIntegratorV2_5.json
│   ├── OmniDragonRegistry.json
│   └── .chainId
├── VRF-DEPLOYMENT-SUMMARY.json    # Complete system overview
└── README.md                      # This file
```

## 🚀 Quick Start

### Get Current Fees
```bash
npx hardhat run scripts/vrf-helper.ts --network sonic
```

### Test System Health
```bash
npx hardhat run scripts/test-vrf-system.ts --network sonic
```

### Make VRF Request
```bash
# Get quote first, then use the fee amount
cast send 0x4cc69C8FEd6d340742a347905ac99DdD5b2B0A90 \
  "requestRandomWordsSimple(uint32)" 30110 \
  --value 0.21ether \
  --rpc-url $RPC_URL_SONIC \
  --private-key $PRIVATE_KEY \
  --legacy
```

## 🔗 Cross-Chain Flow

1. **Sonic**: Request submitted to VRF Integrator
2. **LayerZero V2**: Cross-chain message sent to Arbitrum  
3. **Arbitrum**: VRF Consumer requests from Chainlink VRF v2.5
4. **Chainlink**: Generates randomness and fulfills request
5. **LayerZero V2**: Response sent back to Sonic
6. **Sonic**: Callback executed with random numbers

## 💰 Fee Structure

- **Standard Quote**: ~0.195 ETH
- **Custom Gas Quote**: ~0.151 ETH (200k gas)
- **Recommended**: Add 10% safety margin

Fees vary based on:
- Gas prices on Arbitrum
- LayerZero network congestion  
- Message complexity

## 🔧 Configuration

### Chainlink VRF v2.5
- **Coordinator**: `0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e`
- **Subscription**: Funded and active
- **Key Hash**: 30 gwei lane
- **Network**: Arbitrum

### LayerZero V2
- **Sonic EID**: 30272
- **Arbitrum EID**: 30110  
- **Peers**: Configured bidirectionally
- **Enforced Options**: 200k gas limit

## 📊 Verification

All contracts are verified on their respective block explorers:
- [Sonic VRF Integrator](https://sonicscan.org/address/0x4cc69c8fed6d340742a347905ac99ddd5b2b0a90)
- [Arbitrum VRF Consumer](https://arbiscan.io/address/0x4cc1b5e72b9a5a6d6ce2131b444bb483fa2815c8)

## 🛠️ Integration

### Solidity Integration
```solidity
interface IChainlinkVRFIntegratorV2_5 {
    function quoteSimple() external view returns (MessagingFee memory);
    function requestRandomWordsSimple(uint32 dstEid) external payable returns (bytes32);
}

// Get quote and make request
uint256 fee = integrator.quoteSimple().nativeFee;
bytes32 requestId = integrator.requestRandomWordsSimple{value: fee}(30110);
```

### Frontend Integration
```typescript
const quote = await vrfIntegrator.quoteSimple();
const fee = quote[0]; // Native fee in wei
const tx = await vrfIntegrator.requestRandomWordsSimple(30110, { value: fee });
```

---

**System deployed and maintained by the OmniDragon team** 🐉