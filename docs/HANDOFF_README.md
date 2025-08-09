## OmniDRAGON Docs Handoff

### Purpose
Concise, copy-ready reference for updating public docs and frontend integration. Includes final vanity addresses, LayerZero settings, verified sources, and correct OFT V2 call patterns.

### Networks
- **Ethereum**: chainId 1, EID 30101, Explorer: `https://etherscan.io`
- **Arbitrum**: chainId 42161, EID 30110, Explorer: `https://arbiscan.io`
- **Avalanche**: chainId 43114, EID 30106, Explorer: `https://snowtrace.io`
- **Base**: chainId 8453, EID 30184, Explorer: `https://basescan.org`
- **Sonic**: chainId 146, EID 30332, Explorer: `https://sonicscan.org`

### Core Contracts (Vanity Addresses)
- **DRAGON (OFT V2)**: `0x69821FFA2312253209FdabB3D84f034B697E7777` (same on all chains)
- **OmniDragonRegistry**: `0x6949936442425f4137807Ac5d269e6Ef66d50777` (same on all chains)
- **OmniDragonPriceOracle**: `0x69aaB98503216E16EC72ac3F4B8dfc900cC27777` (all chains)
- **OmniDragonPrimaryOracle (Sonic-only)**: `0x69773eC63Bf4b8892fDEa30D07c91E205866e777`
- **veDRAGON**: `0x6982e7747b0f833C2c5b07aD45D228734c145777` (all chains)
- **OmniDragonJackpotVault**: `0x69352F6940529E00ccc6669606721b07BC659777` (all chains)

### LayerZero V2 Settings
- EIDs: Ethereum 30101, Arbitrum 30110, Avalanche 30106, Base 30184, Sonic 30332
- lzRead channels registered in `OmniDragonRegistry` for all chains
- Enforced LZ receive gas removed (extraOptions can be `0x`), rely on dynamic quotes

### Wrapped Native Tokens (set on OmniDragonJackpotVault)
- Sonic: WS set (tx: `0x2b656f...b2b673`)
- Arbitrum: WETH set (tx: `0x9b8224...a31b1`)
- Ethereum: WETH set (tx: `0x6f4845...2e027`)
- Base: WETH set (tx: `0x902c29...c564c`)
- Avalanche: WAVAX set (tx: `0x6b3f38...72880`)

### Verification Status (Main Contracts)
- Sonic: PrimaryOracle, veDRAGON, OmniDragonJackpotVault verified; PriceOracle already verified
- Arbitrum: PriceOracle & Vault already verified; veDRAGON verified (Sourcify)
- Base: PriceOracle & Vault already verified; veDRAGON verified (Sourcify)
- Avalanche: PriceOracle & Vault already verified; veDRAGON verified (Sourcify)

Useful explorer links:
- Sonic PrimaryOracle: `https://sonicscan.org/address/0x69773eC63Bf4b8892fDEa30D07c91E205866e777`
- Sonic veDRAGON: `https://sonicscan.org/address/0x6982e7747b0f833c2c5b07ad45d228734c145777`
- Sonic Vault: `https://sonicscan.org/address/0x69352F6940529E00ccc6669606721b07bc659777`
- PriceOracle (common):
  - Ethereum: `https://etherscan.io/address/0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`
  - Arbitrum: `https://arbiscan.io/address/0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`
  - Base: `https://basescan.org/address/0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`
  - Avalanche: `https://snowtrace.io/address/0x69aaB98503216E16EC72ac3F4B8dfc900cC27777`

### Correct OFT V2 ABI (Frontend/CLI)
- SendParam: `(uint32 dstEid, bytes32 to, uint256 amountLD, uint256 minAmountLD, bytes extraOptions, bytes composeMsg, bytes oftCmd)`
- MessagingFee: `(uint256 nativeFee, uint256 lzTokenFee)`

#### Quote + Send (example Sonic → Arbitrum 69,420 DRAGON)
```bash
TOKEN=0x69821FFA2312253209FdabB3D84f034B697E7777
TO=0xDDd0050d1E084dFc72d5d06447Cc10bcD3fEF60F
TO_B32=0x000000000000000000000000ddd0050d1e084dfc72d5d06447cc10bcd3fef60f
DST=30110
AMOUNT=$(cast --to-wei 69420 ether)

# quoteSend
QUOTE=$(cast call $TOKEN \
  "quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)" \
  "($DST,$TO_B32,$AMOUNT,$AMOUNT,0x,0x,0x)" false \
  --rpc-url $RPC_URL_SONIC)
NATIVE_FEE_HEX=0x$(echo $QUOTE | sed 's/^0x//' | cut -c1-64)
NATIVE_FEE=$(cast to-dec $NATIVE_FEE_HEX)

# send
cast send $TOKEN \
  "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)" \
  "($DST,$TO_B32,$AMOUNT,$AMOUNT,0x,0x,0x)" "($NATIVE_FEE,0)" $TO \
  --value $NATIVE_FEE \
  --rpc-url $RPC_URL_SONIC \
  --private-key $PRIVATE_KEY
```

Notes:
- Remove enforced extraOptions unless explicitly needed; use quotes to get actual cost.
- If slippage causes revert, set `minAmountLD` slightly lower than `amountLD`.

### LayerZero OFT API (for Frontend)
Reference: `docs/FRONTEND_INTEGRATION.md` (already contains full examples). Key points to surface:
- Use `/list` to discover token deployments by symbol
- Use `/transfer` to obtain `populatedTransaction` and optional `approvalTransaction`
- Chain names via `@layerzerolabs/lz-definitions` `Chain` constants
- Provide LayerZero Scan link for tracking: `https://layerzeroscan.com/tx/<hash>`

### Post-Deploy Configuration (already applied)
- Registry `setLayerZeroEndpoint(uint16,address)` for all chains
- Registry `setPriceOracle(uint16,address)` for non-Sonic chains to common `OmniDragonPriceOracle`
- Registry `configurePrimaryOracle(address,uint32)` on Sonic to `OmniDragonPrimaryOracle`
- Registry `setLzReadChannel(uint16,uint32)` across chains
- OmniDRAGON token wiring: LP pair, fee roles, jackpot vault, revenue distributor, delegate set

### TODO (Docs Team)
- Cross-check and add final explorer verification badges/links for each contract per chain
- Ensure frontend bridging uses the correct OFT V2 ABI fields above
- Surface LayerZero OFT API flow prominently with code samples (TS/ethers)
- Link this handoff from the main deployments README

### Source Files
- Quick reference: `deployments/README.md`
- Frontend guide: `docs/FRONTEND_INTEGRATION.md`


