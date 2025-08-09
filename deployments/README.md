# OmniDragon Deployments

This folder contains deployment information for the OmniDragon OFT token and cross-chain VRF system.

## Quick Links
- Frontend guide (bridging + LayerZero OFT API): [FRONTEND_INTEGRATION.md](../docs/FRONTEND_INTEGRATION.md)

## 🐉 OmniDRAGON (OFT) – Token

- Name: Dragon
- Symbol: DRAGON
- Address (same on all chains): `0x69821FFA2312253209FdabB3D84f034B697E7777`
- Registry (same on all chains): `0x6949936442425f4137807Ac5d269e6Ef66d50777`
- Standard: ERC-20 + LayerZero V2 OFT

### LayerZero V2 EIDs

| Chain | EID |
|------|-----|
| Ethereum | 30101 |
| Arbitrum | 30110 |
| Avalanche | 30106 |
| Base | 30184 |
| Sonic | 30332 |

### Core Dependencies (for fee distribution)

| Chain | OmniDragonJackpotVault | veDRAGONRevenueDistributor |
|------|---------------------|----------------------------|
| Sonic | `0x69352F6940529E00ccc6669606721b07BC659777` | (TBD) |
| Arbitrum | `0x69352F6940529E00ccc6669606721b07BC659777` | (TBD) |
| Ethereum | `0x69352F6940529E00ccc6669606721b07BC659777` | (TBD) |
| Base | `0x69352F6940529E00ccc6669606721b07BC659777` | (TBD) |
| Avalanche | `0x69352F6940529E00ccc6669606721b07BC659777` | (TBD) |

Wrapped native set txs:
- Sonic (WS): 0x2b656fb35ae1b8baa1b9039547cf87d2ced5c6f8e4b333c7560b1ed7e4b2b673
- Arbitrum (WETH): 0x9b8224ea1b73e7113a91886a98bd885d07f348e48826c01331b9d5838b1a31b1
- Ethereum (WETH): 0x6f4845e51d52dad055b5d76e0ec2c51185c53b614140b34c3fc164212982e027
- Base (WETH): 0x902c299eab7a646e9c95a393de9ef2015152cf963231d4892c16848d2f5c564c
- Avalanche (WAVAX): 0x6b3f382823d46f970471aea2bf6ce5823ebe763717201ec5ed0e9e0228072880

### Vanity Core Addresses

- OmniDragonPriceOracle (all chains): `0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`
- OmniDragonPrimaryOracle (Sonic only): `0x69773eC63Bf4b8892fDEa30D07c91E205866e777`
- veDRAGON (all chains, initialize after deploy): `0x6982e7747b0f833C2c5b07aD45D228734c145777`
- OmniDragonJackpotVault (all chains): `0x69352F6940529E00ccc6669606721b07BC659777`

### Registry Oracle Settings

PriceOracle registered per chain (registry `getPriceOracle(chainId)`):
- 42161 (Arbitrum) → `0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`
- 1 (Ethereum) → `0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`
- 8453 (Base) → `0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`
- 43114 (Avalanche) → `0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`

lzRead channel IDs set in registry:
- 146 → 30332, 42161 → 30110, 1 → 30101, 8453 → 30184, 43114 → 30106

### Bridge DRAGON (Foundry cast, correct OFT ABI)

1) Quote fee (example Sonic → Arbitrum 69,420 DRAGON):

```bash
TOKEN=0x69821FFA2312253209FdabB3D84f034B697E7777
TO=0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F
TO_B32=0x000000000000000000000000ddd0050d1e084dfc72d5d06447cc10bcd3fef60f
DST=30110 # Arbitrum EID
AMOUNT=$(cast --to-wei 69420 ether)
QUOTE=$(cast call $TOKEN \
  "quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)" \
  "($DST,$TO_B32,$AMOUNT,$AMOUNT,0x,0x,0x)" false \
  --rpc-url $RPC_URL_SONIC)
# nativeFee is the first 32 bytes
NATIVE_FEE_HEX=0x$(echo $QUOTE | sed 's/^0x//' | cut -c1-64)
NATIVE_FEE=$(cast to-dec $NATIVE_FEE_HEX)
echo "nativeFee: $NATIVE_FEE"
```

2) Send with MessagingFee struct:

```bash
cast send $TOKEN \
  "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)" \
  "($DST,$TO_B32,$AMOUNT,$AMOUNT,0x,0x,0x)" "($NATIVE_FEE,0)" $TO \
  --value $NATIVE_FEE \
  --rpc-url $RPC_URL_SONIC \
  --private-key $PRIVATE_KEY
```

Notes:
- We removed enforced LZ receive gas; extraOptions can be empty (defaults apply).
- If slippage reverts, set `minAmountLD` slightly lower than `amountLD`.

## 📋 Quick Reference

### VRF Contract Addresses

| Contract | Network | Address |
|----------|---------|---------|
| ChainlinkVRFIntegratorV2_5 | Sonic | `0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5` |
| ChainlinkVRFIntegratorV2_5 | Arbitrum | `0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5` |
| ChainlinkVRFIntegratorV2_5 | Ethereum | `0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5` |
| ChainlinkVRFIntegratorV2_5 | BSC | `0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5` |
| ChainlinkVRFIntegratorV2_5 | Avalanche | `0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5` |
| OmniDragonVRFConsumerV2_5 | Arbitrum | `0x697a9d438a5b61ea75aa823f98a85efb70fd23d5` |
| OmniDragonRegistry | All Chains | `0x6949936442425f4137807Ac5d269e6Ef66d50777` |

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
cast send 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5 \
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
- [Sonic VRF Integrator](https://sonicscan.org/address/0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5)
- [Arbitrum VRF Integrator](https://arbiscan.io/address/0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5)
- [Arbitrum VRF Consumer](https://arbiscan.io/address/0x697a9d438a5b61ea75aa823f98a85efb70fd23d5)
- [Ethereum VRF Integrator](https://etherscan.io/address/0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5)
- [BSC VRF Integrator](https://bscscan.com/address/0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5)
- [Avalanche VRF Integrator](https://snowscan.xyz/address/0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5)

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
// Same address on all chains
const VRF_INTEGRATOR = "0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5";

const quote = await vrfIntegrator.quoteSimple();
const fee = quote[0]; // Native fee in wei
const tx = await vrfIntegrator.requestRandomWordsSimple(30110, { value: fee });
```

---

**System deployed and maintained by the OmniDragon team** 🐉