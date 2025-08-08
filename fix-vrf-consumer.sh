#!/bin/bash
# Fix VRF Consumer Configuration

source .env

echo "🔧 Fixing VRF Consumer Configuration..."

# Set VRF Coordinator address first
echo "1. Setting VRF Coordinator..."
cast send 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 \
  "setVRFCoordinator(address)" \
  0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL_ARBITRUM

# Set complete VRF configuration
echo "2. Setting complete VRF config..."
cast send 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 \
  "setVRFConfig(address,uint256,bytes32)" \
  0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e \
  49130512167777098004519592693541429977179420141459329604059253338290818062746 \
  0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL_ARBITRUM

echo "✅ VRF Consumer configuration fixed!"
