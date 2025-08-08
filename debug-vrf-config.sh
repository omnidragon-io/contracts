#!/bin/bash
# Debug VRF Consumer Configuration

source .env

echo "🔍 Checking VRF Consumer Configuration..."

echo "1. VRF Coordinator Address:"
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "vrfCoordinator()" --rpc-url $RPC_URL_ARBITRUM

echo "2. Subscription ID:"
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "subscriptionId()" --rpc-url $RPC_URL_ARBITRUM

echo "3. Key Hash:"
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "keyHash()" --rpc-url $RPC_URL_ARBITRUM

echo "4. Callback Gas Limit:"
cast call 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5 "callbackGasLimit()" --rpc-url $RPC_URL_ARBITRUM

echo ""
echo "Expected values:"
echo "VRF Coordinator: 0x3C0Ca683b403E37668AE3DC4FB62F4B29B6f7a3e"
echo "Subscription ID: 49130512167777098004519592693541429977179420141459329604059253338290818062746"
echo "Key Hash: 0x8472ba59cf7134dfe321f4d61a430c4857e8b19cdd5230b09952a92671c24409"
