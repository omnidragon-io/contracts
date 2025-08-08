# OmniDRAGON Frontend Integration Guide

This guide gives a front-end developer everything needed to integrate bridging and balances for the OmniDRAGON OFT token across chains.

## Token
- Name: Dragon
- Symbol: DRAGON
- Address (same on all chains): `0x69821FFA2312253209FdabB3D84f034B697E7777`
- Standard: ERC-20 + LayerZero V2 OFT

## Registry
- `0x6949936442425f4137807Ac5d269e6Ef66d50777` (same on all chains)

## LayerZero EIDs
- Ethereum: `30101`
- Arbitrum: `30110`
- Avalanche: `30106`
- Base: `30184`
- Sonic: `30332`

## Networks (example RPCs)
- Ethereum: `https://eth.llamarpc.com`
- Arbitrum: `https://arb1.arbitrum.io/rpc`
- Avalanche: `https://api.avax.network/ext/bc/C/rpc`
- Base: `https://mainnet.base.org`
- Sonic: 

## ABI Notes (OFT)
- OFT `SendParam` (struct): `(uint32 dstEid, bytes32 to, uint256 amountLD, uint256 minAmountLD, bytes extraOptions, bytes composeMsg, bytes oftCmd)`
- `quoteSend((...), bool payInLzToken)` returns `(MessagingFee)`; in cast, first 32 bytes are `nativeFee`
- `send((...), (uint256 nativeFee, uint256 lzTokenFee), address refund)` must be called with `value = nativeFee`
- We do NOT enforce receive gas in config; `extraOptions` can be `0x`

## Example (ethers.js v6)
```ts
import { ethers } from 'ethers'

const TOKEN = '0x69821FFA2312253209FdabB3D84f034B697E7777'
const user = '0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F'
const dstEid = 30110 // Arbitrum
const amount = ethers.parseUnits('69420', 18)

const abi = [
  'function balanceOf(address) view returns (uint256)',
  'function quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool) view returns (uint256 nativeFee, uint256 lzTokenFee)',
  'function send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address) payable returns (bytes32, (uint256,uint256))'
]

const provider = new ethers.JsonRpcProvider('https://eu.endpoints.matrixed.link/rpc/sonic?auth=...')
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider)
const token = new ethers.Contract(TOKEN, abi, signer)

const toBytes32 = (addr: string) => ethers.zeroPadValue(addr, 32)
const sendParam = [dstEid, toBytes32(user), amount, amount, '0x', '0x', '0x']

const [nativeFee] = await token.quoteSend(sendParam, false)

const tx = await token.send(sendParam, [nativeFee, 0n], user, { value: nativeFee })
await tx.wait()
```

## Example (cast)
```bash
TOKEN=0x69821FFA2312253209FdabB3D84f034B697E7777
TO=0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F
TO_B32=0x000000000000000000000000ddd0050d1e084dfc72d5d06447cc10bcd3fef60f
DST=30110
AMOUNT=$(cast --to-wei 69420 ether)
QUOTE=$(cast call $TOKEN "quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)" "($DST,$TO_B32,$AMOUNT,$AMOUNT,0x,0x,0x)" false --rpc-url $RPC_URL_SONIC)
NATIVE_FEE_HEX=0x$(echo $QUOTE | sed 's/^0x//' | cut -c1-64)
NATIVE_FEE=$(cast to-dec $NATIVE_FEE_HEX)
cast send $TOKEN "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)" "($DST,$TO_B32,$AMOUNT,$AMOUNT,0x,0x,0x)" "($NATIVE_FEE,0)" $TO --value $NATIVE_FEE --rpc-url $RPC_URL_SONIC --private-key $PRIVATE_KEY
```

## Confirming Credit
- After send, check destination chain balance:
```bash
cast call 0x69821FFA2312253209FdabB3D84f034B697E7777 "balanceOf(address)" $TO --rpc-url $RPC_URL_ARBITRUM
```

## Current Known Addresses
- Token: `0x69821FFA2312253209FdabB3D84f034B697E7777` (all chains)
- Registry: `0x6949936442425f4137807Ac5d269e6Ef66d50777` (all chains)
- Sonic dependencies:
  - JackpotVault: `0x09a5d89539fdd07f779a3ddc3a985d0a757b4d7b`
  - RevenueDistributor: `0x4b0b4a25844744bbb23424533ca5a7f6dfaaba57`
- Arbitrum dependencies:
  - JackpotVault: `0x21f2c71190330d8e6ececb411f05195874274dc9`
  - RevenueDistributor: `0x8b89562e46502fc31addcace5b99367083c5c0c1`

## UX Notes
- Bridge flow: select destination chain → quote fee → send → show pending status → poll destination balance.
- Gas optimization: no enforced receive gas; rely on defaults. For high complexity payloads, pass extraOptions if needed later.
- All chains use the same token address; no per-chain mapping needed.
 
---

## LayerZero OFT Transfer API Usage Guide
A developer guide to using the LayerZero OFT Transfer API to orchestrate OFT transfers between chains. See: [LayerZero OFT API](https://docs.layerzero.network/v2/tools/api/oft).

### Key Benefits
- Universal API (EVM ↔ EVM, Solana ↔ EVM, EVM ↔ Solana)
- Token discovery via `/list`
- Pre-built transaction data via `/transfer`
- Built-in validation and message tracking

### Install
```bash
npm i ethers axios dotenv @layerzerolabs/lz-definitions
```

### .env
```bash
OFT_API_KEY=your-api-key-here
PRIVATE_KEY=your-private-key-here
```

### Endpoints
- List: `GET https://metadata.layerzero-api.com/v1/metadata/experiment/ofts/list`
- Transfer: `GET https://metadata.layerzero-api.com/v1/metadata/experiment/ofts/transfer` (header: `x-layerzero-api-key`)

### Discover Tokens (/list)
```ts
import axios from 'axios'
const API_BASE_URL = 'https://metadata.layerzero-api.com/v1/metadata/experiment/ofts'
const res = await axios.get(`${API_BASE_URL}/list`, { params: { symbols: 'DRAGON' } })
const tokenData = res.data['DRAGON']?.[0]
const availableChains = Object.keys(tokenData.deployments)
```

### Generate Transfer Tx (/transfer)
```ts
import axios from 'axios'
import { ethers } from 'ethers'

const API_KEY = process.env.OFT_API_KEY!
const API_BASE_URL = 'https://metadata.layerzero-api.com/v1/metadata/experiment/ofts'

const fromChain = 'sonic'
const toChain = 'arbitrum'
const oftAddress = tokenData.deployments[fromChain].address

const response = await axios.get(`${API_BASE_URL}/transfer`, {
  params: {
    srcChainName: fromChain,
    dstChainName: toChain,
    srcAddress: oftAddress,
    amount: '69420000000000000000000',
    from: wallet.address,
    to: wallet.address,
    validate: true,
  },
  headers: { 'x-layerzero-api-key': API_KEY },
})

const { transactionData } = response.data
if (transactionData.approvalTransaction) {
  const tx = await wallet.sendTransaction(transactionData.approvalTransaction)
  await tx.wait()
}
const tx2 = await wallet.sendTransaction(transactionData.populatedTransaction)
await tx2.wait()
```

### Optional extraOptions
```ts
const response = await axios.get(`${API_BASE_URL}/transfer`, {
  params: {
    srcChainName: fromChain,
    dstChainName: toChain,
    srcAddress: oftAddress,
    amount: '1000000000000000000',
    from: wallet.address,
    to: wallet.address,
    validate: true,
    options: JSON.stringify({
      executor: {
        lzReceive: { gasLimit: 300000 },
        nativeDrops: [{ amount: '1000000000000000', receiver: wallet.address }],
      },
    }),
  },
  headers: { 'x-layerzero-api-key': API_KEY },
})
```

### Track Messages (LayerZero Scan API)
- Base URL: `https://scan.layerzero-api.com/v1`
- Example: `GET /messages/tx/{tx}`

Notes:
- Amount must satisfy min conversion per shared/local decimals
- Ensure native balance for fees and token balance for the amount
