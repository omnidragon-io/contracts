// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// LayerZero Read imports
import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ReadCodecV1, EVMCallRequestV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {OAppRead} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppRead.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Custom Errors for gas optimization
error InvalidMode();
error NotConfigured();
error InvalidPeer();
error InvalidPair();
error InvalidOracle();
error InvalidPrice();
error InsufficientSources();
error InvalidRecipient();
error TransferFailed();
error EmergencyActive();

// Optimized interfaces
interface AggregatorV3Interface {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function decimals() external view returns (uint8);
}

interface IPythNetworkPriceFeeds {
    function getPriceUnsafe(bytes32 id) external view returns (int64 price, uint64 conf, int32 expo, uint256 publishTime);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IOmniDragonRegistry {
    function getLayerZeroEndpoint(uint16 _chainId) external view returns (address);
    function getOracleConfig(uint16 _chainId) external view returns (address primaryOracle, uint32 primaryChainEid, uint32 lzReadChannelId, bool isConfigured);
}

/**
 * @title OmniDragonOracle
 * @author 0xakita.eth
 * @dev Multi-chain Oracle with LayerZero Read integration 
 * @notice oracle.omnidragon.io
 */
contract OmniDragonOracle is Ownable, OAppRead, OAppOptionsType3, ReentrancyGuard {
    enum OracleMode { UNINITIALIZED, PRIMARY, SECONDARY }
    enum OracleType { PULL_ORACLE, PUSH_ORACLE }
    enum OracleId { CHAINLINK_NATIVE_USD, PYTH_NATIVE_USD, BAND_NATIVE_USD, API3_NATIVE_USD }

    // Packed struct to optimize storage
    struct OracleConfig {
        address feedAddress;
        bytes32 identifier;
        uint32 staleness;
        uint8 weight;
        OracleType oracleType;
        bool isActive;
    }

    // Packed core state - fits in 2 storage slots
    struct CoreState {
        address registry;           // 20 bytes
        uint32 readChannel;         // 4 bytes
        uint8 minValidSources;      // 1 byte
        uint8 dragonDecimals;       // 1 byte
        uint8 nativeDecimals;       // 1 byte
        OracleMode mode;            // 1 byte
        bool emergencyMode;         // 1 byte
        bool priceInitialized;      // 1 byte
        bool isDragonToken0;        // 1 byte
        uint32 twapPeriod;          // 4 bytes
    }
    
    CoreState public state;
    
    // Price data
    int256 public latestPrice;
    int256 public latestNativePrice;
    uint256 public lastUpdateTime;
    int256 public fallbackPrice;
    uint256 public fallbackPriceTimestamp;
    
    // DEX pair info
    address public dragonNativePair;
    address public secondaryDragonNativePair;
    address public dragonToken;
    address public nativeToken;
    
    // Oracle configurations
    mapping(OracleId => OracleConfig) private _oracles;
    
    // Cross-chain peer data
    mapping(uint32 => address) public peerOracles;
    mapping(uint32 => bool) public activePeers;
    uint32[] public activePeerEids;
    mapping(uint32 => int256) public peerDragonPrices;
    mapping(uint32 => uint256) public peerPriceTimestamps;
    
    // Constants
    uint16 constant READ_TYPE = 1;
    uint256 constant FALLBACK_MAX_AGE = 24 hours;
    
    event ModeChanged(OracleMode oldMode, OracleMode newMode);
    event PriceUpdated(int256 dragonPrice, int256 nativePrice, uint256 timestamp);
    event CrossChainPriceReceived(uint32 indexed targetEid, int256 dragonPrice, int256 nativePrice, uint256 timestamp);

    constructor(address _registry, address _layerZeroEndpoint, address _initialOwner)
        OAppRead(_registry != address(0) ? IOmniDragonRegistry(_registry).getLayerZeroEndpoint(uint16(block.chainid)) : _layerZeroEndpoint, _initialOwner)
        Ownable(_initialOwner) {
        state = CoreState({
            registry: _registry,
            readChannel: 4294967295,
            minValidSources: 2,
            dragonDecimals: 0,
            nativeDecimals: 0,
            mode: OracleMode.PRIMARY,
            emergencyMode: false,
            priceInitialized: false,
            isDragonToken0: false,
            twapPeriod: 1800
        });
        _setPeer(state.readChannel, AddressCast.toBytes32(address(this)));
    }
    
    function setMode(OracleMode newMode) external onlyOwner {
        if (newMode == state.mode || newMode == OracleMode.UNINITIALIZED) revert InvalidMode();
        OracleMode oldMode = state.mode;
        state.mode = newMode;
        emit ModeChanged(oldMode, newMode);
    }
    
    function toggleEmergencyMode() external onlyOwner {
        state.emergencyMode = !state.emergencyMode;
    }
    
    function syncChannel() external onlyOwner {
        uint16 chainId = uint16(block.chainid);
        (,, uint32 lzReadChannelId, bool isConfigured) = IOmniDragonRegistry(state.registry).getOracleConfig(chainId);
        if (!isConfigured || lzReadChannelId == 0) revert NotConfigured();
        setReadChannel(lzReadChannelId, true);
    }
    
    function setReadChannel(uint32 _channelId, bool _active) public override onlyOwner {
        if (_channelId > 0 && _active) {
            _setPeer(_channelId, AddressCast.toBytes32(address(this)));
        }
        state.readChannel = _channelId;
    }

    function setPeer(uint32 _eid, bytes32 _peer) public override onlyOwner {
        super.setPeer(_eid, _peer);
        _handlePeerUpdate(_eid, _peer);
    }

    function _handlePeerUpdate(uint32 _eid, bytes32 _peer) internal {
        address oracle = AddressCast.toAddress(_peer);
        bool active = _peer != bytes32(0);
        bool wasActive = activePeers[_eid];
        peerOracles[_eid] = oracle;
        activePeers[_eid] = active;
        
        if (active != wasActive) {
            if (active) {
                activePeerEids.push(_eid);
            } else {
                uint256 length = activePeerEids.length;
                for (uint256 i = 0; i < length; i++) {
                    if (activePeerEids[i] == _eid) {
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
    
    function requestPrice(uint32 _targetEid, bytes calldata _extraOptions) external payable returns (MessagingReceipt memory receipt) {
        if (state.readChannel == 0 || !activePeers[_targetEid] || peerOracles[_targetEid] == address(0)) revert InvalidPeer();
        
        bytes memory cmd = _buildReadCommand(_targetEid, peerOracles[_targetEid]);
        
        return _lzSend(
            state.readChannel,
            cmd,
            combineOptions(state.readChannel, READ_TYPE, _extraOptions),
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
    }
    
    function quoteFee(uint32 _targetEid, bytes calldata _extraOptions) external view returns (MessagingFee memory fee) {
        if (state.readChannel == 0 || !activePeers[_targetEid] || peerOracles[_targetEid] == address(0)) revert InvalidPeer();

        bytes memory cmd = _buildReadCommand(_targetEid, peerOracles[_targetEid]);

        return _quote(
            state.readChannel,
            cmd,
            combineOptions(state.readChannel, READ_TYPE, _extraOptions),
            false
        );
    }

    function setPair(address _pairAddress, address _dragonToken, address _nativeToken) external onlyOwner {
        if (_pairAddress == address(0) || _dragonToken == address(0) || _nativeToken == address(0)) revert InvalidPair();

        (address t0, address t1) = (IUniswapV2Pair(_pairAddress).token0(), IUniswapV2Pair(_pairAddress).token1());
        if ((t0 != _dragonToken || t1 != _nativeToken) && (t0 != _nativeToken || t1 != _dragonToken)) revert InvalidPair();
        
        dragonNativePair = _pairAddress;
        dragonToken = _dragonToken;
        nativeToken = _nativeToken;
        state.isDragonToken0 = (t0 == _dragonToken);
        
        state.dragonDecimals = IERC20Metadata(_dragonToken).decimals();
        state.nativeDecimals = IERC20Metadata(_nativeToken).decimals();
    }
    
    function setPullOracle(OracleId oracle, bool isActive, uint8 weight, uint32 staleness, address feedAddress, bytes32 priceId) external onlyOwner {
        if (uint8(oracle) > 1) revert InvalidOracle();
        
        _oracles[oracle] = OracleConfig({
            feedAddress: feedAddress,
            identifier: priceId,
            staleness: staleness,
            weight: weight,
            oracleType: OracleType.PULL_ORACLE,
            isActive: isActive
        });
    }
    
    function setPushOracle(OracleId oracle, bool isActive, uint8 weight, uint32 staleness, address feedAddress, bytes32 symbol) external onlyOwner {
        if (uint8(oracle) < 2 || uint8(oracle) > 3) revert InvalidOracle();
        
        _oracles[oracle] = OracleConfig({
            feedAddress: feedAddress,
            identifier: symbol,
            staleness: staleness,
            weight: weight,
            oracleType: OracleType.PUSH_ORACLE,
            isActive: isActive
        });
    }
    
    // Removed legacy getLatestPrice()
    
    function updatePrice() external {
        if (state.mode != OracleMode.PRIMARY || state.emergencyMode) revert EmergencyActive();

        (int256 dragonUsd18, bool isValid) = _calculateDragonPrice();
        if (!isValid) revert InvalidPrice();

        (int256 nativeUsd18,) = _calculateNativeTokenPrice();
        latestPrice = dragonUsd18;
        latestNativePrice = nativeUsd18;
        lastUpdateTime = block.timestamp;
        state.priceInitialized = true;

        emit PriceUpdated(dragonUsd18, nativeUsd18, block.timestamp);
    }

    // Simple, chain-agnostic getters
    function getDragonPrice() external view returns (int256 price, uint256 timestamp) {
        (int256 dragon, , uint256 ts, bool ok) = _getPricesFresh();
        return (ok ? dragon : int256(0), ok ? ts : 0);
    }

    function getNativePrice() external view returns (int256 price, uint256 timestamp) {
        (, int256 native, uint256 ts, bool ok) = _getPricesFresh();
        return (ok ? native : int256(0), ok ? ts : 0);
    }

    // Back-compat helpers
    function getDragonPriceWithNative() external view returns (int256 dragonPrice, int256 nativePrice, uint256 timestamp) {
        (int256 d, int256 n, uint256 ts, bool ok) = _getPricesFresh();
        return (ok ? d : int256(0), ok ? n : int256(0), ok ? ts : 0);
    }

    function getNativeTokenPrice() external view returns (int256 price, bool isValid, uint256 timestamp) {
        (, int256 n, uint256 ts, bool ok) = _getPricesFresh();
        return (ok ? n : int256(0), ok, ok ? ts : 0);
    }
    
    /**
     * @notice Peer oracle price (cross-chain result)
     * @dev Returns DRAGON/USD from a peer oracle on eid. Native price is not tracked for peers.
     */
    function getPeerDragonPrice(uint32 _eid) public view returns (int256 dragonPrice, uint256 timestamp, bool isValid) {
        dragonPrice = peerDragonPrices[_eid];
        timestamp = peerPriceTimestamps[_eid];
        isValid = activePeers[_eid] && timestamp > 0 && block.timestamp <= timestamp + 3600;
    }

    function validate() external view returns (bool localValid, bool crossChainValid) {
        localValid = state.priceInitialized && (block.timestamp <= lastUpdateTime + 3600);
        if (!localValid) return (false, false);
        
        uint256 validPeers = 0;
        uint256 len = activePeerEids.length;
        for (uint256 i = 0; i < len; i++) {
            (,, bool valid) = getPeerDragonPrice(activePeerEids[i]);
            if (valid) validPeers++;
        }
        crossChainValid = validPeers > 0;
    }
    
    function setMinValidSources(uint8 _minSources) external onlyOwner {
        if (_minSources == 0 || _minSources > 4) revert InvalidOracle();
        state.minValidSources = _minSources;
    }

    function withdraw(address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        if (recipient == address(0) || amount == 0 || address(this).balance < amount) revert InvalidRecipient();
        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
    
    function withdrawAll(address payable recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert InvalidRecipient();
        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidRecipient();
        (bool ok, ) = recipient.call{value: balance}("");
        if (!ok) revert TransferFailed();
    }
    
    function getOracleConfig(OracleId id) external view returns (OracleConfig memory) {
        return _oracles[id];
    }
    
    function _calculateDragonPrice() internal returns (int256 price18, bool isValid) {
        if (state.mode == OracleMode.SECONDARY) {
            return (latestPrice, state.priceInitialized);
        }
        
        (int256 nativeUsd18, bool nativeValid) = _calculateNativeTokenPrice();
        if (!nativeValid) return (0, false);
        
        (int256 dragonPerNative18, bool dragonValid) = _getDragonNativeRatio();
        if (!dragonValid) return (0, false);
        
        // Convert: nativeUsd18 (USD per wS) and dragonPerNative18 (DRAGON per wS)
        // DRAGON/USD = (USD per wS) / (DRAGON per wS)
        int256 dragonUsd18 = (nativeUsd18 * 1e18) / dragonPerNative18;
        return (dragonUsd18, true);
    }
    
    function _calculateNativeTokenPrice() internal returns (int256 price18, bool isValid) {
        int256 totalWeightedPrice = 0;
        uint256 totalWeight = 0;
        uint256 validSources = 0;

        // Check each oracle type
        for (uint8 i = 0; i < 4; i++) {
            OracleId oracleId = OracleId(i);
            (int256 price, bool ok) = _readOracle(oracleId);
            if (ok && price > 0) {
                uint8 w = _oracles[oracleId].weight;
                totalWeightedPrice += price * int256(uint256(w));
                totalWeight += w;
                validSources++;
            }
        }

        if (validSources < state.minValidSources) {
            if (validSources == 1 && state.minValidSources > 1 && totalWeight > 0) {
                return (totalWeightedPrice / int256(totalWeight), true);
            }
            
            if (fallbackPrice > 0 && block.timestamp <= fallbackPriceTimestamp + FALLBACK_MAX_AGE) {
                return (fallbackPrice, true);
            }
            
            return (0, false);
        }
        
        int256 calculatedPrice = totalWeightedPrice / int256(totalWeight);
        
        if (calculatedPrice > 0) {
            fallbackPrice = calculatedPrice;
            fallbackPriceTimestamp = block.timestamp;
        }
        
        return (calculatedPrice, true);
    }
    
    function _getDragonNativeRatio() internal view returns (int256 ratio18, bool isValid) {
        (int256 rPrimary, uint256 nativeResPrimary, bool okPrimary) = _getDragonNativeRatioFromPair(dragonNativePair);
        if (!okPrimary) {
            return (0, false);
        }
        if (secondaryDragonNativePair == address(0)) {
            return (rPrimary, true);
        }
        (int256 rSecondary, uint256 nativeResSecondary, bool okSecondary) = _getDragonNativeRatioFromPair(secondaryDragonNativePair);
        if (!okSecondary || nativeResSecondary == 0) {
            return (rPrimary, true);
        }
        uint256 totalNative = nativeResPrimary + nativeResSecondary;
        int256 weighted = (rPrimary * int256(nativeResPrimary) + rSecondary * int256(nativeResSecondary)) / int256(totalNative);
        return (weighted, true);
    }

    function _getDragonNativeRatioFromPair(address pair) internal view returns (int256 ratio18, uint256 nativeReserve, bool ok) {
        if (pair == address(0)) return (0, 0, false);
        try IUniswapV2Pair(pair).getReserves() returns (uint112 r0, uint112 r1, uint32) {
            if (r0 == 0 || r1 == 0) return (0, 0, false);
            address t0 = IUniswapV2Pair(pair).token0();
            address t1 = IUniswapV2Pair(pair).token1();
            bool isDragon0 = (t0 == dragonToken && t1 == nativeToken);
            bool isNative0 = (t0 == nativeToken && t1 == dragonToken);
            if (!isDragon0 && !isNative0) return (0, 0, false);
            uint256 dragonReserve = isDragon0 ? uint256(r0) : uint256(r1);
            nativeReserve = isDragon0 ? uint256(r1) : uint256(r0);
            if (nativeReserve == 0) return (0, 0, false);
            if (state.nativeDecimals >= state.dragonDecimals) {
                uint256 decAdj = 10 ** uint256(state.nativeDecimals - state.dragonDecimals);
                ratio18 = int256((dragonReserve * decAdj * 1e18) / nativeReserve);
            } else {
                uint256 decAdj = 10 ** uint256(state.dragonDecimals - state.nativeDecimals);
                ratio18 = int256((dragonReserve * 1e18) / (nativeReserve * decAdj));
            }
            return (ratio18, nativeReserve, true);
        } catch {
            return (0, 0, false);
        }
    }

    function setSecondaryPair(address _pairAddress) external onlyOwner {
        if (_pairAddress == address(0)) {
            secondaryDragonNativePair = address(0);
            return;
        }
        (address t0, address t1) = (IUniswapV2Pair(_pairAddress).token0(), IUniswapV2Pair(_pairAddress).token1());
        if (!((t0 == dragonToken && t1 == nativeToken) || (t0 == nativeToken && t1 == dragonToken))) revert InvalidPair();
        secondaryDragonNativePair = _pairAddress;
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
                return _readBand(config.feedAddress, config.staleness, config.identifier);
            } else if (uint8(oracle) == 3) {
                return _readAPI3(config.feedAddress, config.staleness);
            }
        }
        
        return (0, false);
    }
    
    function _readChainlink(address feed, uint32 maxStale) internal view returns (int256 price18, bool ok) {
        try AggregatorV3Interface(feed).latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
            if (answer > 0 && block.timestamp <= updatedAt + maxStale) {
                try AggregatorV3Interface(feed).decimals() returns (uint8 d) {
                    if (d <= 18) {
                        return (answer * int256(10 ** (18 - uint256(d))), true);
                    } else {
                        return (answer / int256(10 ** (uint256(d) - 18)), true);
                    }
                } catch {
                    return (answer * 1e10, true);
                }
            }
        } catch {}
        return (0, false);
    }
    
    function _readPyth(address pyth, uint32 maxStale, bytes32 priceId) internal view returns (int256 price18, bool ok) {
        // Pyth price representation: real = price * 10^expo
        // To scale to 1e18: scaled = price * 10^(18 + expo)
        try IPythNetworkPriceFeeds(pyth).getPriceUnsafe(priceId) returns (int64 price, uint64, int32 expo, uint256 publishTime) {
            if (price <= 0 || block.timestamp > publishTime + maxStale) return (0, false);

            int256 e = int256(int32(expo));
            int256 adj = 18 + e;
            if (adj >= 0) {
                return (int256(price) * int256(10 ** uint256(adj)), true);
            } else {
                return (int256(price) / int256(10 ** uint256(uint256(-adj))), true);
            }
        } catch {
            return (0, false);
        }
    }
    
    function _readBand(address ref, uint32 maxStale, bytes32 symbol) internal view returns (int256 price18, bool ok) {
        // Inline Band Protocol calls for bytecode optimization
        bytes memory symbolStr = abi.encodePacked(symbol);
        
        // Try packet consumer first
        (bool success, bytes memory data) = ref.staticcall(abi.encodeWithSignature("prices(string)", string(symbolStr)));
        if (success && data.length >= 64) {
            (uint64 price, int64 timestamp) = abi.decode(data, (uint64, int64));
            if (price != 0 && block.timestamp <= uint256(uint64(timestamp)) + maxStale) {
                return (int256(uint256(price) * 1e9), true);
            }
        }
        
        // Try reference data fallback
        (success, data) = ref.staticcall(abi.encodeWithSignature("getReferenceData(string,string)", string(symbolStr), "USD"));
        if (success && data.length >= 96) {
            (uint256 rate, uint256 lastUpdatedBase, uint256 lastUpdatedQuote) = abi.decode(data, (uint256, uint256, uint256));
            uint256 lastUpdated = lastUpdatedBase > lastUpdatedQuote ? lastUpdatedBase : lastUpdatedQuote;
            if (rate != 0 && block.timestamp <= lastUpdated + maxStale) {
                return (int256(rate), true);
            }
        }
        
        return (0, false);
    }
    
    function _readAPI3(address proxy, uint32 maxStale) internal view returns (int256 price18, bool ok) {
        (bool success, bytes memory data) = proxy.staticcall(abi.encodeWithSignature("read()"));
        if (success && data.length >= 64) {
            (int224 value, uint32 timestamp) = abi.decode(data, (int224, uint32));
            if (value > 0 && block.timestamp <= timestamp + maxStale) {
                return (int256(value), true);
            }
        }
        return (0, false);
    }
    
    // Public helpers to expose individual source prices (scaled to 1e18)
    function readChainlink() external view returns (int256 price18, bool ok) {
        OracleConfig memory cfg = _oracles[OracleId.CHAINLINK_NATIVE_USD];
        if (!cfg.isActive) return (0, false);
        return _readChainlink(cfg.feedAddress, cfg.staleness);
    }
    
    function readPyth() external view returns (int256 price18, bool ok) {
        OracleConfig memory cfg = _oracles[OracleId.PYTH_NATIVE_USD];
        if (!cfg.isActive) return (0, false);
        return _readPyth(cfg.feedAddress, cfg.staleness, cfg.identifier);
    }
    
    function readBand() external view returns (int256 price18, bool ok) {
        OracleConfig memory cfg = _oracles[OracleId.BAND_NATIVE_USD];
        if (!cfg.isActive) return (0, false);
        return _readBand(cfg.feedAddress, cfg.staleness, cfg.identifier);
    }
    
    function readAPI3() external view returns (int256 price18, bool ok) {
        OracleConfig memory cfg = _oracles[OracleId.API3_NATIVE_USD];
        if (!cfg.isActive) return (0, false);
        return _readAPI3(cfg.feedAddress, cfg.staleness);
    }
    
    // Public helper to expose current DRAGON/native DEX ratio (scaled to 1e18)
    function readDexRatio() external view returns (int256 ratio18, bool ok) {
        return _getDragonNativeRatio();
    }
    
    function _buildReadCommand(uint32 _targetEid, address _targetOracle) internal view returns (bytes memory) {
        EVMCallRequestV1[] memory req = new EVMCallRequestV1[](1);
        
        req[0] = EVMCallRequestV1({
            appRequestLabel: 1,
            targetEid: _targetEid,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: _targetOracle,
            callData: abi.encodeWithSignature("getDragonPrice()")
        });
        
        return ReadCodecV1.encode(0, req);
    }
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        (int256 dragonPrice, uint256 dragonTs) = abi.decode(_message, (int256, uint256));
        
        uint32 targetEid = _origin.srcEid;
        if (dragonTs == 0) revert InvalidPrice();
        
        peerDragonPrices[targetEid] = dragonPrice;
        peerPriceTimestamps[targetEid] = dragonTs;
        
        if (state.mode == OracleMode.SECONDARY && dragonPrice > 0) {
            latestPrice = dragonPrice;
            lastUpdateTime = dragonTs;
            state.priceInitialized = true;
        }
        
        emit CrossChainPriceReceived(targetEid, dragonPrice, 0, dragonTs);
    }

    // Internal: single fresh-price source
    function _getPricesFresh() internal view returns (int256 dragon, int256 native, uint256 ts, bool ok) {
        bool fresh = state.priceInitialized && block.timestamp <= lastUpdateTime + 86400 && latestPrice > 0 && latestNativePrice >= 0;
        if (!fresh) {
            return (0, 0, 0, false);
        }
        return (latestPrice, latestNativePrice, lastUpdateTime, true);
    }
}
