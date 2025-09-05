// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OmniDragonOracle
 * @author 0xakita.eth
 * @dev Multi-chain Oracle with LayerZero Read integration 
 * @notice oracle.omnidragon.io
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
 
// LayerZero Read imports
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {MessagingFee, MessagingReceipt, MessagingParams} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ReadCodecV1, EVMCallRequestV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Interfaces for different oracle types
interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}

// Band Protocol PacketConsumer interface (newer format)
interface IPacketConsumer {
    struct Price {
        uint64 price;      // The price value; in the format of 1e9
        int64 timestamp;   // UNIX timestamp when the price was last updated
    }

    function prices(string calldata _s) external view returns (Price memory);
}

// Band Protocol Reference interface (older format, used by Sonic Band contract)
interface IBandProtocolReference {
    function getReferenceData(string memory _base, string memory _quote) external view returns (uint256 rate, uint256 lastUpdatedBase, uint256 lastUpdatedQuote);
}

interface IAPI3Proxy {
    function read() external view returns (int224 value, uint32 timestamp);
}

interface IPythNetworkPriceFeeds {
    struct Price { int64 price; uint64 conf; int32 expo; uint256 publishTime; }
    function getPriceUnsafe(bytes32 id) external view returns (Price memory);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
}

// Interface for cross-chain Oracle reading
interface IOmniDragonOracle {
    function getLatestPrice() external view returns (int256 price, uint256 timestamp);
}

// Interface for OmniDragonRegistry (matches real deployed registry)
interface IOmniDragonRegistry {
    struct OracleConfig {
        address primaryOracle;
        uint32 primaryChainEid;
        uint32 lzReadChannelId;
        bool isConfigured;
    }

    function getLayerZeroEndpoint(uint16 _chainId) external view returns (address);
    function getOracleConfig(uint16 _chainId) external view returns (OracleConfig memory);
}

contract OmniDragonOracle is Ownable, OAppRead, OAppOptionsType3 {
    enum OracleMode { UNINITIALIZED, PRIMARY, SECONDARY }
    enum OracleType { PULL_ORACLE, PUSH_ORACLE }
    enum OracleId { CHAINLINK_NATIVE_USD, PYTH_NATIVE_USD, BAND_NATIVE_USD, API3_NATIVE_USD }

    OracleMode public mode;
    bool public emergencyMode;
    
    struct OracleConfig {
        bool isActive;
        OracleType oracleType;
        uint8 weight;
        uint32 staleness;
        address feedAddress;
        bytes32 identifier;
        string symbol;
    }
       
    mapping(OracleId => OracleConfig) private _oracles;
    address public dragonNativePair;
    address public dragonToken;
    address public nativeToken;
    address public registry;
    bool public isDragonToken0;
    bool public twapEnabled;
    bool public priceInitialized;
    uint8 public dragonDecimals;
    uint8 public nativeDecimals;
    uint16 public constant READ_TYPE = 1;
    uint32 public twapPeriod;
    uint32 public readChannel;
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public lastUpdateTime;
    int256 public twapRatio18;
    int256 public latestPrice;
    int256 public latestNativeUsdPrice18;
    mapping(uint32 => address) public peerOracles;
    mapping(uint32 => bool) public activePeers;
    uint32[] public activePeerEids;
    mapping(uint32 => int256) public peerDragonPrices;
    mapping(uint32 => int256) public peerNativePrices;
    mapping(uint32 => uint256) public peerPriceTimestamps;
    
    uint8 public minValidSources = 2; // Configurable minimum valid oracle sources
    
    int256 public fallbackPrice;
    uint256 public fallbackPriceTimestamp;
    uint256 public constant FALLBACK_MAX_AGE = 24 hours;
    
    event ModeChanged(OracleMode oldMode, OracleMode newMode);
    event PriceUpdated(int256 dragonPrice, int256 nativePrice, uint256 timestamp);
    event CrossChainPriceReceived(uint32 indexed targetEid, int256 dragonPrice, int256 nativePrice, uint256 timestamp);
    event CrossChainPriceValidation(bool localValid, bool crossChainValid, int256 priceDifference);
    event PriceRequested(bytes32 indexed guid, uint32 indexed targetEid, address indexed sender, uint256 fee);
    
    event PairUpdated(address indexed oldPair, address indexed newPair, address dragonToken, address nativeToken);
    event TWAPToggled(bool enabled);
    event TWAPPeriodUpdated(uint32 oldPeriod, uint32 newPeriod);
    event MinValidSourcesUpdated(uint8 oldMin, uint8 newMin);
    event TWAPUpdateFailed(string reason);
    event OracleSourceDegraded(uint256 validSources, uint256 required);
    event UsingFallbackPrice(int256 price, uint256 timestamp);
    
    // Debug events for peer update troubleshooting
    event PeerUpdateDebug(uint32 indexed eid, address oracle, bool active, bool wasActive);
    event ArrayUpdateDebug(uint32 indexed eid, bool adding, uint256 arrayLength);
    
    constructor(address _registry, address _initialOwner)
        OAppRead(IOmniDragonRegistry(_registry).getLayerZeroEndpoint(uint16(block.chainid)), _initialOwner)
        Ownable(_initialOwner) {
        registry = _registry;
        mode = OracleMode.SECONDARY;
        twapPeriod = 1800;

        // Initialize LayerZero Read channel properly
        readChannel = 4294967295; // LayerZero Read Channel
        _setPeer(readChannel, AddressCast.toBytes32(address(this)));
    }
    
    function setMode(OracleMode newMode) external onlyOwner {
        if (newMode == mode) revert();
        require(newMode != OracleMode.UNINITIALIZED, "Cannot set mode to UNINITIALIZED");
        OracleMode oldMode = mode;
        mode = newMode;
        emit ModeChanged(oldMode, newMode);
        if (newMode == OracleMode.PRIMARY && dragonNativePair != address(0) && blockTimestampLast == 0) {
            _initTWAP();
        }
    }
    
    function toggleEmergencyMode() external onlyOwner {
        emergencyMode = !emergencyMode;
    }
    
    /**
     * @dev Check if oracle mode is properly initialized
     * @return true if mode is set to PRIMARY or SECONDARY, false if UNINITIALIZED
     */
    function isModeInitialized() external view returns (bool) {
        return mode != OracleMode.UNINITIALIZED;
    }
    
    function syncChannel() external onlyOwner {
        uint16 chainId = uint16(block.chainid);
        IOmniDragonRegistry.OracleConfig memory cfg = IOmniDragonRegistry(registry).getOracleConfig(chainId);
        if (!cfg.isConfigured || cfg.lzReadChannelId == 0) revert();
        setReadChannel(cfg.lzReadChannelId, true);
    }
    
    function setReadChannel(uint32 _channelId, bool _active) public override onlyOwner {
        _setPeer(_channelId, _active ? AddressCast.toBytes32(address(this)) : bytes32(0));
        readChannel = _channelId;
    }
    
    /**
     * @notice Custom peer management for oracle tracking
     * @dev Called internally when peers are set via inherited setPeer
     * @param _eid The endpoint ID of the peer chain  
     * @param _peer The peer address as bytes32 (zero to disable)
     */
    function _handlePeerUpdate(uint32 _eid, bytes32 _peer) internal {
        address oracle = AddressCast.toAddress(_peer);
        bool active = _peer != bytes32(0);
        
        emit PeerUpdateDebug(_eid, oracle, active, activePeers[_eid]);

        bool wasActive = activePeers[_eid];
        peerOracles[_eid] = oracle;
        activePeers[_eid] = active;
        
        // Fixed array manipulation with bounds checking
        if (active != wasActive) {
            emit ArrayUpdateDebug(_eid, active, activePeerEids.length);
            
            if (active) {
                // Adding new active peer
                activePeerEids.push(_eid);
            } else {
                // Removing active peer - improved logic
                uint256 length = activePeerEids.length;
                if (length > 0) {
                    for (uint256 i = 0; i < length; i++) {
                        if (activePeerEids[i] == _eid) {
                            // Move last element to current position and pop
                            if (i != length - 1) {
                                activePeerEids[i] = activePeerEids[length - 1];
                            }
                            activePeerEids.pop();
                            break;
                        }
                    }
                }
            }
        }
    }

    /**
     * @notice Override setPeer to add our oracle tracking
     * @param _eid The endpoint ID of the peer chain
     * @param _peer The peer address as bytes32 (zero to disable)
     */
    function setPeer(uint32 _eid, bytes32 _peer) public override onlyOwner {
        // Call parent implementation first
        super.setPeer(_eid, _peer);
        // Then handle our custom logic
        _handlePeerUpdate(_eid, _peer);
    }

    /**
     * @notice LayerZero CLI compatible getPeer function
     * @dev Returns peer as address instead of bytes32 for CLI compatibility
     * @param _eid The endpoint ID of the peer chain
     * @return peer The peer address
     */
    function getPeer(uint32 _eid) public view returns (address peer) {
        return AddressCast.toAddress(peers[_eid]);
    }
    
    /**
     * @dev Manual function to fix existing peer mappings (emergency use)
     */
    function emergencyFixPeerMapping(uint32 _eid) external onlyOwner {
        bytes32 peerBytes32 = peers[_eid];
        address oracle = AddressCast.toAddress(peerBytes32);
        bool active = peerBytes32 != bytes32(0);
        
        // Directly update the mappings
        peerOracles[_eid] = oracle;
        activePeers[_eid] = active;
        
        // Update the array if needed
        bool inArray = false;
        for (uint256 i = 0; i < activePeerEids.length; i++) {
            if (activePeerEids[i] == _eid) {
                inArray = true;
                break;
            }
        }
        
        if (active && !inArray) {
            activePeerEids.push(_eid);
        } else if (!active && inArray) {
            // Remove from array
            for (uint256 i = 0; i < activePeerEids.length; i++) {
                if (activePeerEids[i] == _eid) {
                    activePeerEids[i] = activePeerEids[activePeerEids.length - 1];
                    activePeerEids.pop();
                    break;
                }
            }
        }
        
        emit PeerUpdateDebug(_eid, oracle, active, false);
    }
    
    function requestPrice(uint32 _targetEid, bytes calldata _extraOptions) external payable returns (MessagingReceipt memory receipt) {
        if (readChannel == 0) revert();
        if (!activePeers[_targetEid]) revert();
        if (peerOracles[_targetEid] == address(0)) revert();
        
        address targetOracle = peerOracles[_targetEid];
        bytes memory cmd = _buildReadCommand(_targetEid, targetOracle);
        
        // Use combineOptions to merge enforced options with caller-provided options
        // This is the correct pattern from LayerZero Read documentation
        MessagingReceipt memory msgReceipt = _lzSend(
            readChannel,
            cmd,
            combineOptions(readChannel, READ_TYPE, _extraOptions),
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        // Emit PriceRequested event for LayerZero processing
        emit PriceRequested(msgReceipt.guid, _targetEid, msg.sender, msg.value);
        
        return msgReceipt;
    }
    
    function quoteFee(uint32 _targetEid, bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        if (readChannel == 0) revert();
        if (!activePeers[_targetEid]) revert();
        if (peerOracles[_targetEid] == address(0)) revert();

        address targetOracle = peerOracles[_targetEid];
        bytes memory cmd = _buildReadCommand(_targetEid, targetOracle);

        // Use combineOptions to merge enforced options with caller-provided options
        return _quote(
            readChannel,
            cmd,
            combineOptions(readChannel, READ_TYPE, _extraOptions),
            false
        );
    }

    /**
     * @notice LayerZero CLI compatible quoteReadFee function
     * @dev Wrapper around quoteFee for CLI compatibility
     */
    function quoteReadFee(uint32 _targetEid, bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        return this.quoteFee(_targetEid, _extraOptions);
    }

    /**
     * @notice LayerZero CLI compatible read function
     * @dev Wrapper around requestPrice for CLI compatibility
     */
    function readSum(uint32 _targetEid, bytes calldata _extraOptions) external payable returns (MessagingReceipt memory) {
        return this.requestPrice(_targetEid, _extraOptions);
    }


    function setPair(address _pairAddress, address _dragonToken, address _nativeToken) external onlyOwner {
        if (_pairAddress == address(0)) revert();
        if (_dragonToken == address(0)) revert();
        if (_nativeToken == address(0)) revert();

        (address t0, address t1) = (IUniswapV2Pair(_pairAddress).token0(), IUniswapV2Pair(_pairAddress).token1());
        if (!((t0 == _dragonToken && t1 == _nativeToken) || (t0 == _nativeToken && t1 == _dragonToken))) revert();
        
        address oldPair = dragonNativePair;
        dragonNativePair = _pairAddress;
        dragonToken = _dragonToken;
        nativeToken = _nativeToken;
        isDragonToken0 = (t0 == _dragonToken);
        
        dragonDecimals = IERC20Metadata(_dragonToken).decimals();
        nativeDecimals = IERC20Metadata(_nativeToken).decimals();
        
        if (mode == OracleMode.PRIMARY) _initTWAP();
        
        emit PairUpdated(oldPair, _pairAddress, _dragonToken, _nativeToken);
    }
    
    function setTWAP(bool _enabled) external onlyOwner {
        twapEnabled = _enabled;
        emit TWAPToggled(_enabled);
        if (_enabled && dragonNativePair != address(0) && blockTimestampLast == 0) {
            _initTWAP();
        }
    }
    
    function setPeriod(uint32 _period) external onlyOwner {
        if (_period < 300) revert();
        if (_period > 86400) revert();
        uint32 oldPeriod = twapPeriod;
        twapPeriod = _period;
        emit TWAPPeriodUpdated(oldPeriod, _period);
    }
    
    function setPullOracle(OracleId oracle, bool isActive, uint8 weight, uint32 staleness, address feedAddress, bytes32 priceId) external onlyOwner {
        if (uint8(oracle) > 1) revert();
        
        _oracles[oracle] = OracleConfig({
            isActive: isActive,
            oracleType: OracleType.PULL_ORACLE,
            weight: weight,
            staleness: staleness,
            feedAddress: feedAddress,
            identifier: priceId,
            symbol: ""
        });
        

    }
    
    function setPushOracle(OracleId oracle, bool isActive, uint8 weight, uint32 staleness, address feedAddress, string memory symbol) external onlyOwner {
        if (uint8(oracle) < 2 || uint8(oracle) > 3) revert();
        
        _oracles[oracle] = OracleConfig({
            isActive: isActive,
            oracleType: OracleType.PUSH_ORACLE,
            weight: weight,
            staleness: staleness,
            feedAddress: feedAddress,
            identifier: bytes32(0),
            symbol: symbol
        });
        

    }
    
    function getLatestPrice() external view returns (int256 price, uint256 timestamp) {
        // LayerZero Read friendly - return graceful values instead of reverting
        if (!priceInitialized) {
            return (0, 0); // Not initialized yet
        }
        
        if (latestPrice <= 0) {
            return (0, 0); // Invalid price
        }
        
        // 24 hours staleness
        if (block.timestamp > lastUpdateTime + 86400) {
            return (0, 0); // Too stale
        }
        
        return (latestPrice, lastUpdateTime);
    }
    
    function updatePrice() external {
        if (mode != OracleMode.PRIMARY) revert();
        if (emergencyMode) revert();

        _updateTWAP();

        (int256 dragonUsd18, bool isValid) = _calculateDragonPrice();
        if (!isValid) revert();

        (int256 nativeUsd18, bool nativeValid) = _calculateNativeTokenPrice();
        latestPrice = dragonUsd18;
        if (nativeValid) latestNativeUsdPrice18 = nativeUsd18;
        lastUpdateTime = block.timestamp;
        priceInitialized = true;

        emit PriceUpdated(dragonUsd18, nativeUsd18, block.timestamp);
    }
    
    function getPrice(uint32 _eid) external view returns (
        int256 dragonPrice, 
        int256 nativePrice, 
        uint256 timestamp, 
        bool isValid
    ) {
        dragonPrice = peerDragonPrices[_eid];
        nativePrice = peerNativePrices[_eid];
        timestamp = peerPriceTimestamps[_eid];
        

        isValid = activePeers[_eid] && 
                  timestamp > 0 && 
                  block.timestamp <= timestamp + 3600;
    }
    
    function validate() external view returns (bool localValid, bool crossChainValid) {
        localValid = priceInitialized && (block.timestamp <= lastUpdateTime + 3600);
        if (!localValid) return (false, false);

        uint256 validPeers = 0;
        for (uint256 i = 0; i < activePeerEids.length; i++) {
            (,, , bool valid) = this.getPrice(activePeerEids[i]);
            if (valid) validPeers++;
        }
        crossChainValid = validPeers > 0;
    }
    
    function setMinValidSources(uint8 _minSources) external onlyOwner {
        require(_minSources > 0 && _minSources <= 4, "Invalid min sources");
        uint8 oldMin = minValidSources;
        minValidSources = _minSources;
        emit MinValidSourcesUpdated(oldMin, _minSources);
    }
    
    receive() external payable {}
    
    fallback() external payable {}
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function withdraw(address payable recipient, uint256 amount) external onlyOwner {
        if (recipient == address(0)) revert();
        if (amount == 0) revert();
        if (address(this).balance < amount) revert();

        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert();
    }
    
    function withdrawAll(address payable recipient) external onlyOwner {
        if (recipient == address(0)) revert();

        uint256 balance = address(this).balance;
        if (balance == 0) revert();

        (bool ok, ) = recipient.call{value: balance}("");
        if (!ok) revert();
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool ok, ) = payable(owner()).call{value: balance}("");
            if (!ok) revert();
        }
    }
    
    function getOracleConfig(OracleId id) external view returns (OracleConfig memory) {
        return _oracles[id];
    }
    
    // Frontend-friendly functions to expose individual oracle prices
    function getChainlinkPrice() external view returns (int256 price, bool isValid) {
        return _readOracle(OracleId.CHAINLINK_NATIVE_USD);
    }
    
    function getPythPrice() external view returns (int256 price, bool isValid) {
        return _readOracle(OracleId.PYTH_NATIVE_USD);
    }
    
    function getBandPrice() external view returns (int256 price, bool isValid) {
        return _readOracle(OracleId.BAND_NATIVE_USD);
    }
    
    function getAPI3Price() external view returns (int256 price, bool isValid) {
        return _readOracle(OracleId.API3_NATIVE_USD);
    }
    
    function getOraclePrice(OracleId oracleId) external view returns (int256 price, bool isValid) {
        return _readOracle(oracleId);
    }
    
    // Get all oracle prices at once for efficient frontend calls
    function getAllOraclePrices() external view returns (
        int256 chainlinkPrice, bool chainlinkValid,
        int256 pythPrice, bool pythValid,
        int256 bandPrice, bool bandValid,
        int256 api3Price, bool api3Valid
    ) {
        (chainlinkPrice, chainlinkValid) = _readOracle(OracleId.CHAINLINK_NATIVE_USD);
        (pythPrice, pythValid) = _readOracle(OracleId.PYTH_NATIVE_USD);
        (bandPrice, bandValid) = _readOracle(OracleId.BAND_NATIVE_USD);
        (api3Price, api3Valid) = _readOracle(OracleId.API3_NATIVE_USD);
    }
    
    function _initTWAP() internal {
        // Optimized: Early return and combined try-catch
        if (dragonNativePair == address(0)) return;

        IUniswapV2Pair pair = IUniswapV2Pair(dragonNativePair);
        try pair.price0CumulativeLast() returns (uint256 p0) {
            try pair.price1CumulativeLast() returns (uint256 p1) {
                (, , uint32 ts) = pair.getReserves();
                price0CumulativeLast = p0;
                price1CumulativeLast = p1;
                blockTimestampLast = ts;
            } catch {}
        } catch {}
    }
    
    function _updateTWAP() internal {
        if (!twapEnabled || dragonNativePair == address(0) || blockTimestampLast == 0) return;

        IUniswapV2Pair pair = IUniswapV2Pair(dragonNativePair);
        try pair.price0CumulativeLast() returns (uint256 price0Cumulative) {
            try pair.price1CumulativeLast() returns (uint256 price1Cumulative) {
                (, , uint32 blockTimestamp) = pair.getReserves();
                uint32 timeElapsed = blockTimestamp - blockTimestampLast;

                if (timeElapsed >= twapPeriod && timeElapsed > 0) {
                    uint256 price0Average = price0Cumulative >= price0CumulativeLast ?
                        (price0Cumulative - price0CumulativeLast) / timeElapsed : 0;
                    uint256 price1Average = price1Cumulative >= price1CumulativeLast ?
                        (price1Cumulative - price1CumulativeLast) / timeElapsed : 0;

                    if ((isDragonToken0 && price1Average > 0) || (!isDragonToken0 && price0Average > 0)) {
                        // Calculate base TWAP ratio
                        int256 baseRatio = int256(((isDragonToken0 ? price1Average : price0Average) * 1e18) >> 112);
                        
                        // Apply decimals adjustment
                        if (nativeDecimals >= dragonDecimals) {
                            twapRatio18 = baseRatio * int256(10 ** uint256(nativeDecimals - dragonDecimals));
                        } else {
                            twapRatio18 = baseRatio / int256(10 ** uint256(dragonDecimals - nativeDecimals));
                        }
                    }

                    price0CumulativeLast = price0Cumulative;
                    price1CumulativeLast = price1Cumulative;
                    blockTimestampLast = blockTimestamp;
                }
            } catch {
                emit TWAPUpdateFailed("price1CumulativeLast");
            }
        } catch {
            emit TWAPUpdateFailed("price0CumulativeLast");
        }
    }
    
    function _calculateDragonPrice() internal returns (int256 price18, bool isValid) {
        if (mode == OracleMode.SECONDARY) {
            return (latestPrice, priceInitialized);
        }
        
        (int256 nativeUsd18, bool nativeValid) = _calculateNativeTokenPrice();
        if (!nativeValid) return (0, false);
        
        (int256 dragonPerNative18, bool dragonValid) = _getDragonNativeRatio();
        if (!dragonValid) return (0, false);
        
        // Dragon_USD = Native_USD * Dragon_per_Native
        int256 dragonUsd18 = (nativeUsd18 * dragonPerNative18) / 1e18;
        return (dragonUsd18, true);
    }
    
    function _calculateNativeTokenPrice() internal returns (int256 price18, bool isValid) {
        int256 totalWeightedPrice = 0;
        uint256 totalWeight = 0;
        uint256 validSources = 0;

        (int256 price, bool ok) = _readOracle(OracleId.CHAINLINK_NATIVE_USD);
        if (ok && price > 0) {
            uint8 w = _oracles[OracleId.CHAINLINK_NATIVE_USD].weight;
            totalWeightedPrice += price * int256(uint256(w));
            totalWeight += w;
            validSources++;
        }

        (price, ok) = _readOracle(OracleId.PYTH_NATIVE_USD);
        if (ok && price > 0) {
            uint8 w = _oracles[OracleId.PYTH_NATIVE_USD].weight;
            totalWeightedPrice += price * int256(uint256(w));
            totalWeight += w;
            validSources++;
        }

        (price, ok) = _readOracle(OracleId.BAND_NATIVE_USD);
        if (ok && price > 0) {
            uint8 w = _oracles[OracleId.BAND_NATIVE_USD].weight;
            totalWeightedPrice += price * int256(uint256(w));
            totalWeight += w;
            validSources++;
        }

        (price, ok) = _readOracle(OracleId.API3_NATIVE_USD);
        if (ok && price > 0) {
            uint8 w = _oracles[OracleId.API3_NATIVE_USD].weight;
            totalWeightedPrice += price * int256(uint256(w));
            totalWeight += w;
            validSources++;
        }

        // Use configurable threshold instead of hardcoded 2
        if (validSources < minValidSources) {
            // If we have at least 1 valid source and fallback is allowed
            if (validSources == 1 && minValidSources > 1) {
                // Emit warning event
                emit OracleSourceDegraded(validSources, minValidSources);
                
                // Use the single source with extra staleness tolerance
                if (totalWeight > 0) {
                    return (totalWeightedPrice / int256(totalWeight), true);
                }
            }
            
            // Try fallback price if recent enough
            if (fallbackPrice > 0 && block.timestamp <= fallbackPriceTimestamp + FALLBACK_MAX_AGE) {
                emit UsingFallbackPrice(fallbackPrice, fallbackPriceTimestamp);
                return (fallbackPrice, true);
            }
            
            return (0, false);
        }
        
        int256 calculatedPrice = totalWeightedPrice / int256(totalWeight);
        
        // Update fallback price on successful calculation
        if (calculatedPrice > 0) {
            fallbackPrice = calculatedPrice;
            fallbackPriceTimestamp = block.timestamp;
        }
        
        return (calculatedPrice, true);
    }
    
    function _getDragonNativeRatio() internal view returns (int256 ratio18, bool isValid) {
        if (dragonNativePair == address(0)) return (0, false);
        
        // TWAP fast-path (already includes decimals adjustment from _updateTWAP)
        if (twapEnabled && twapRatio18 > 0 && blockTimestampLast > 0) {
            if (block.timestamp <= blockTimestampLast + (twapPeriod * 2)) {
                return (twapRatio18, true);
            }
        }
        
        // Spot price calculation with decimals adjustment
        try IUniswapV2Pair(dragonNativePair).getReserves() returns (uint112 r0, uint112 r1, uint32) {
            if (r0 == 0 || r1 == 0) return (0, false);
            uint256 dragonReserve = isDragonToken0 ? uint256(r0) : uint256(r1);
            uint256 nativeReserve = isDragonToken0 ? uint256(r1) : uint256(r0);
            if (nativeReserve == 0) return (0, false);
            
            // ratio = (dragon/native) * 1e18 * 10^(nativeDec - dragonDec)
            if (nativeDecimals >= dragonDecimals) {
                uint256 decAdj = 10 ** uint256(nativeDecimals - dragonDecimals);
                ratio18 = int256((dragonReserve * decAdj * 1e18) / nativeReserve);
            } else {
                uint256 decAdj = 10 ** uint256(dragonDecimals - nativeDecimals);
                ratio18 = int256((dragonReserve * 1e18) / (nativeReserve * decAdj));
            }
            return (ratio18, true);
        } catch {
            return (0, false);
        }
    }
    
    function _readOracle(OracleId oracle) internal view returns (int256 price18, bool ok) {
        OracleConfig memory config = _oracles[oracle];
        if (!config.isActive) return (0, false);
        
        if (config.oracleType == OracleType.PULL_ORACLE) {
            if (uint8(oracle) == 0) {
                return _readChainlink(config.feedAddress, config.staleness);
            } else if (uint8(oracle) == 1) {
                return _readPyth(config.feedAddress, config.staleness, config.identifier);
            }
        } else if (config.oracleType == OracleType.PUSH_ORACLE) {
            if (uint8(oracle) == 2) {
                return _readBand(config.feedAddress, config.staleness, config.symbol);
            } else if (uint8(oracle) == 3) {
                return _readAPI3(config.feedAddress, config.staleness);
            }
        }
        
        return (0, false);
    }
    
    function _readChainlink(address feed, uint32 maxStale) internal view returns (int256 price18, bool ok) {
        try AggregatorV3Interface(feed).latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
            if (answer > 0 && block.timestamp <= updatedAt + maxStale) {
                // Get decimals dynamically
                try AggregatorV3Interface(feed).decimals() returns (uint8 d) {
                    if (d <= 18) {
                        return (answer * int256(10 ** (18 - uint256(d))), true);
                    } else {
                        return (answer / int256(10 ** (uint256(d) - 18)), true);
                    }
                } catch {
                    // Fallback to assuming 8 decimals if decimals() fails
                    return (answer * 1e10, true);
                }
            }
        } catch {}
        return (0, false);
    }
    
    function _readPyth(address pyth, uint32 maxStale, bytes32 priceId) internal view returns (int256 price18, bool ok) {
        try IPythNetworkPriceFeeds(pyth).getPriceUnsafe(priceId) returns (IPythNetworkPriceFeeds.Price memory price) {
            if (price.price <= 0 || block.timestamp > price.publishTime + maxStale) return (0, false);
            
            // Pyth price format: actual_price = price.price * 10^price.expo
            // We want: price_1e18 = actual_price * 10^18
            // Therefore: price_1e18 = price.price * 10^(price.expo + 18)
            
            int256 targetExpo = 18;
            int256 currentExpo = price.expo;
            
            if (currentExpo == targetExpo) {
                return (price.price, true);
            } else if (currentExpo < targetExpo) {
                // Need to multiply by 10^(targetExpo - currentExpo)
                return (price.price * int256(10 ** uint256(targetExpo - currentExpo)), true);
            } else {
                // Need to divide by 10^(currentExpo - targetExpo)
                return (price.price / int256(10 ** uint256(currentExpo - targetExpo)), true);
            }
        } catch {
            return (0, false);
        }
    }
    
    function _readBand(address ref, uint32 maxStale, string memory symbol) internal view returns (int256 price18, bool ok) {
        try IPacketConsumer(ref).prices(symbol) returns (IPacketConsumer.Price memory price) {
            if (price.price == 0 || block.timestamp > uint256(uint64(price.timestamp)) + maxStale) return (0, false);
            return (int256(uint256(price.price) * 1e9), true); // Convert 1e9 to 1e18
        } catch {
            // Optimized: Simplified fallback - assume symbol is already in correct format
            try IBandProtocolReference(ref).getReferenceData(symbol, "USD") returns (uint256 rate, uint256 lastUpdatedBase, uint256 lastUpdatedQuote) {
                if (rate == 0 || block.timestamp > (lastUpdatedBase > lastUpdatedQuote ? lastUpdatedBase : lastUpdatedQuote) + maxStale) return (0, false);
                return (int256(rate), true); // Already 1e18
            } catch {
                return (0, false);
            }
        }
    }
    
    function _readAPI3(address proxy, uint32 maxStale) internal view returns (int256 price18, bool ok) {
        try IAPI3Proxy(proxy).read() returns (int224 value, uint32 timestamp) {
            if (value > 0 && block.timestamp <= timestamp + maxStale) return (int256(value), true); // Already 1e18
        } catch {}
        return (0, false);
    }
    
    // --- Request decoding helpers ---
    
    function _buildReadCommand(uint32 _targetEid, address _targetOracle) internal view returns (bytes memory) {
        EVMCallRequestV1[] memory req = new EVMCallRequestV1[](1);
        
        req[0] = EVMCallRequestV1({
            appRequestLabel: 1,
            targetEid: _targetEid,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: _targetOracle,
            callData: abi.encodeWithSelector(IOmniDragonOracle.getLatestPrice.selector)
        });
        
        // No compute processing needed - just simple read
        return ReadCodecV1.encode(0, req);
    }
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        // LayerZero Read responses only contain (int256 price, uint256 timestamp)
        (int256 dragonPrice, uint256 dragonTs) = abi.decode(_message, (int256, uint256));
        
        uint32 targetEid = _origin.srcEid;
        
        // Validate timestamp
        if (dragonTs == 0) revert(); // Only require dragon timestamp since native is not requested
        
        peerDragonPrices[targetEid] = dragonPrice;
        peerNativePrices[targetEid] = 0; // No native price in LayerZero Read response
        
        uint256 latestTimestamp = dragonTs; // Only using dragon timestamp since native is not requested
        peerPriceTimestamps[targetEid] = latestTimestamp;
        
        // Update local price for SECONDARY mode
        if (mode == OracleMode.SECONDARY && dragonPrice > 0) {
            latestPrice = dragonPrice;
            lastUpdateTime = latestTimestamp;
            priceInitialized = true;
        }
        
        emit CrossChainPriceReceived(targetEid, dragonPrice, 0, latestTimestamp);
        
        if (priceInitialized && mode == OracleMode.PRIMARY) {
            bool localValid = block.timestamp <= lastUpdateTime + 3600;
            bool crossChainValid = block.timestamp <= latestTimestamp + 3600;
            
            int256 priceDifference = 0;
            if (localValid && crossChainValid) {
                priceDifference = latestPrice - dragonPrice;
            }
            
            emit CrossChainPriceValidation(localValid, crossChainValid, priceDifference);
        }
    }
}
