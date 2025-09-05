// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IOAppCore } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";
import { EnforcedOptionParam } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppOptionsType3.sol";

/**
 * @title IOmniDragonOracle
 * @dev Unified interface for OmniDragon Oracle with LayerZero compatibility
 * @notice Combines price oracle functionality with LayerZero cross-chain features
 */
interface IOmniDragonOracle is IOAppCore {
    // ============ Price Oracle Functions ============
    
    /**
     * @dev Get the latest DRAGON/USD price
     * @return price The price in 18 decimals
     * @return timestamp The timestamp of the last price update
     */
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
    
    /**
     * @dev Update the price (triggers price refresh)
     * @return success Whether the price update was successful
     */
    function updatePrice() external returns (bool success);
    
    /**
     * @dev Get the native token (e.g., Sonic) USD price
     * @return price The price in 18 decimals
     * @return isValid Whether the price is valid and fresh
     * @return timestamp The timestamp of the last price update
     */
    function getNativeTokenPrice() external view returns (int256 price, bool isValid, uint256 timestamp);
    
    /**
     * @dev Get both DRAGON and Native prices in one call
     * @return dragonPrice The DRAGON/USD price in 18 decimals
     * @return nativePrice The Native/USD price in 18 decimals
     * @return timestamp The timestamp of the last price update
     */
    function getLatestPriceWithNative() external view returns (
        int256 dragonPrice,
        int256 nativePrice, 
        uint256 timestamp
    );
    
    // ============ LayerZero Functions ============
    
    /**
     * @dev Set peer oracle on another chain (LayerZero CLI compatible)
     * @param _eid Endpoint ID of the target chain
     * @param _peer Address of the peer oracle as bytes32
     */
    function setPeer(uint32 _eid, bytes32 _peer) external;
    
    /**
     * @dev Set delegate for LayerZero operations
     * @param _delegate Address of the delegate
     */
    function setDelegate(address _delegate) external;
    
    /**
     * @dev Set enforced options for LayerZero messages
     * @param _enforcedOptions Array of enforced option parameters
     */
    function setEnforcedOptions(EnforcedOptionParam[] calldata _enforcedOptions) external;
    
    // ============ Oracle Configuration ============
    
    /**
     * @dev Get the LayerZero Read channel ID
     * @return The current read channel ID
     */
    function readChannel() external view returns (uint32);
    
    /**
     * @dev Set the LayerZero Read channel
     * @param _channelId The channel ID to set
     * @param _active Whether the channel is active
     */
    function setReadChannel(uint32 _channelId, bool _active) external;
    
    /**
     * @dev Get the oracle mode (PRIMARY or SECONDARY)
     * @return The current mode (0=UNINITIALIZED, 1=PRIMARY, 2=SECONDARY)
     */
    function mode() external view returns (uint8);
    
    /**
     * @dev Set the oracle mode
     * @param newMode The new mode to set
     */
    function setMode(uint8 newMode) external;
    
    // ============ Peer Management ============
    
    /**
     * @dev Get the peer oracle address for a specific chain
     * @param _eid Endpoint ID of the target chain
     * @return The peer oracle address
     */
    function peerOracles(uint32 _eid) external view returns (address);
    
    /**
     * @dev Check if a peer is active
     * @param _eid Endpoint ID of the target chain
     * @return Whether the peer is active
     */
    function activePeers(uint32 _eid) external view returns (bool);
    
    // ============ Events ============
    
    event PriceUpdated(int256 dragonPrice, int256 nativePrice, uint256 timestamp);
    event ModeChanged(uint8 oldMode, uint8 newMode);
    event PeerUpdateDebug(uint32 indexed eid, address oracle, bool active, bool wasActive);
}