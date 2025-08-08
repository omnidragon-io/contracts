# 🔍 VRF System Debug Checklist

## Transaction: https://arbiscan.io/tx/0x65fbad90d5088b3fc004ca47a7dcf7acaf3a1d6d15d21e5681d19acbebaff7a6

### Quick Debug Commands

```bash
# 1. Check VRF Coordinator is set correctly
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "vrfCoordinator()" --rpc-url $RPC_URL_ARBITRUM

# 2. Check subscription ID
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "subscriptionId()" --rpc-url $RPC_URL_ARBITRUM

# 3. Check if VRF Consumer has ETH balance
cast balance 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 --rpc-url $RPC_URL_ARBITRUM

# 4. Check latest sequence processed
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "sequenceToRequestId(uint64)" 4 --rpc-url $RPC_URL_ARBITRUM

# 5. Verify peer configuration for Sonic
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "peers(uint32)" 30332 --rpc-url $RPC_URL_ARBITRUM
```

### Expected Values:
- **VRF Coordinator**: `0x000000000000000000000000003c0ca683b403e37668ae3dc4fb62f4b29b6f7a3e`
- **Subscription ID**: `49130512167777098004519592693541429977179420141459329604059253338290818062746`
- **ETH Balance**: > 0 (should have ~0.017 ETH)
- **Sequence 4**: Should be 0 (not processed yet)
- **Sonic Peer**: `0x0000000000000000000000002bd68f5e956ca9789a7ab7674670499e65140bd5`

### Potential Issues:

1. **VRF Coordinator Still Not Set** - Most likely cause
2. **Subscription Authorization** - VRF Consumer not added to subscription
3. **Gas Limit Too Low** - LayerZero message doesn't have enough gas
4. **Message Format** - Cross-chain message encoding issue
5. **Contract Balance** - Not enough ETH for internal operations

### Manual Fix (if VRF Coordinator is 0x000...):

```bash
# Reset VRF configuration completely
cast send 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 \
  "setVRFConfig(address,uint256,bytes32)" \
  0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e \
  49130512167777098004519592693541429977179420141459329604059253338290818062746 \
  0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL_ARBITRUM
```
