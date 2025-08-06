// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/config/IOmniDragonRegistry.sol";

/**
 * @title OmniDragonRegistry
 * @author 0xakita.eth
 * @dev Registry for omniDRAGON deployment
 *
 * Provides:
 * - Deterministic address calculation via CREATE2
 * - Basic chain configuration storage
 * - LayerZero configuration during deployment
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract OmniDragonRegistry is IOmniDragonRegistry, Ownable {
  // Basic chain configuration storage
  mapping(uint16 => IOmniDragonRegistry.ChainConfig) private chainConfigs;
  uint16[] private supportedChains;
  uint16 private currentChainId;

  // Add mapping to prevent DoS on getSupportedChains
  mapping(uint16 => bool) public isSupportedChain;
  uint256 public constant MAX_SUPPORTED_CHAINS = 50; // Prevent DoS

  // LayerZero endpoint mapping
  mapping(uint256 => uint32) public chainIdToEid;
  mapping(uint32 => uint256) public eidToChainId;
  mapping(uint16 => address) public layerZeroEndpoints;

  // LayerZero configuration events (events from interface are inherited)
  event CurrentChainSet(uint16 indexed chainId);
  event LayerZeroConfigured(address indexed oapp, uint32 indexed eid, string configType);
  event LayerZeroLibrarySet(address indexed oapp, uint32 indexed eid, address lib, string libraryType);

  // Custom errors
  error ChainAlreadyRegistered(uint16 chainId);
  error ChainNotRegistered(uint16 chainId);
  error ZeroAddress();

  // LayerZero V2 struct definitions
  struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
  }

  constructor(address _initialOwner) Ownable(_initialOwner) {
    currentChainId = uint16(block.chainid); // Use actual chain ID

    // Use common LayerZero v2 endpoint for deterministic deployment
    // This will be updated to chain-specific endpoints after deployment
    address commonEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;

    layerZeroEndpoints[146] = commonEndpoint; // Sonic (will update to 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B)
    layerZeroEndpoints[42161] = commonEndpoint; // Arbitrum (correct: 0x1a44076050125825900e736c501f859c50fE728c)
    layerZeroEndpoints[43114] = commonEndpoint; // Avalanche (correct: 0x1a44076050125825900e736c501f859c50fE728c)
  }

  /**
   * @dev Get default wrapped native token symbol based on chain ID
   * @param _chainId The chain ID
   * @return symbol The default wrapped native token symbol
   */
  function _getDefaultWrappedNativeSymbol(uint256 _chainId) internal pure returns (string memory) {
    if (_chainId == 146) return "WS"; // Sonic
    if (_chainId == 43114) return "WAVAX"; // Avalanche
    if (_chainId == 42161) return "WETH"; // Arbitrum
    if (_chainId == 250) return "WFTM"; // Fantom
    if (_chainId == 137) return "WMATIC"; // Polygon
    if (_chainId == 1) return "WETH"; // Ethereum
    if (_chainId == 56) return "WBNB"; // BSC
    if (_chainId == 10) return "WETH"; // Optimism
    if (_chainId == 8453) return "WETH"; // Base
    if (_chainId == 59144) return "WETH"; // Linea
    if (_chainId == 5000) return "WETH"; // Mantle
    if (_chainId == 239) return "TAC"; // TAC
    return "WNATIVE"; // Generic fallback
  }

  /**
   * @notice Set the current chain ID
   */
  function setCurrentChainId(uint16 _chainId) external onlyOwner {
    currentChainId = _chainId;
    emit CurrentChainSet(_chainId);
  }

  /**
   * @notice Register a new chain configuration
   */
  function registerChain(
    uint16 _chainId,
    string calldata _chainName,
    address _wrappedNativeToken,
    address _uniswapV2Router,
    address _uniswapV2Factory,
    bool _isActive
  ) external override onlyOwner {
    if (chainConfigs[_chainId].chainId == _chainId) {
      revert ChainAlreadyRegistered(_chainId);
    }

    if (supportedChains.length >= MAX_SUPPORTED_CHAINS) {
      revert("Too many chains");
    }

    chainConfigs[_chainId] = IOmniDragonRegistry.ChainConfig({
      chainId: _chainId,
      chainName: _chainName,
      wrappedNativeToken: _wrappedNativeToken,
      wrappedNativeSymbol: _getDefaultWrappedNativeSymbol(_chainId),
      uniswapV2Router: _uniswapV2Router,
      uniswapV2Factory: _uniswapV2Factory,
      isActive: _isActive
    });

    supportedChains.push(_chainId);
    isSupportedChain[_chainId] = true;

    emit ChainRegistered(_chainId, _chainName);
  }

  /**
   * @notice Update existing chain configuration
   */
  function updateChain(
    uint16 _chainId,
    string calldata _chainName,
    address _wrappedNativeToken,
    address _uniswapV2Router,
    address _uniswapV2Factory
  ) external override onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) {
      revert ChainNotRegistered(_chainId);
    }

    chainConfigs[_chainId].chainName = _chainName;
    chainConfigs[_chainId].wrappedNativeToken = _wrappedNativeToken;
    chainConfigs[_chainId].wrappedNativeSymbol = _getDefaultWrappedNativeSymbol(_chainId);
    chainConfigs[_chainId].uniswapV2Router = _uniswapV2Router;
    chainConfigs[_chainId].uniswapV2Factory = _uniswapV2Factory;

    emit ChainUpdated(_chainId);
  }

  /**
   * @notice Update chain wrapped native symbol
   */
  function updateWrappedNativeSymbol(uint16 _chainId, string calldata _symbol) external onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) {
      revert ChainNotRegistered(_chainId);
    }
    chainConfigs[_chainId].wrappedNativeSymbol = _symbol;
    emit ChainUpdated(_chainId);
  }

  /**
   * @notice Set chain active status
   */
  function setChainStatus(uint16 _chainId, bool _isActive) external override onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) {
      revert ChainNotRegistered(_chainId);
    }

    chainConfigs[_chainId].isActive = _isActive;
    emit ChainStatusChanged(_chainId, _isActive);
  }

  /**
   * @notice Get chain configuration
   */
  function getChainConfig(
    uint16 _chainId
  ) external view override returns (IOmniDragonRegistry.ChainConfig memory) {
    if (chainConfigs[_chainId].chainId != _chainId) {
      revert ChainNotRegistered(_chainId);
    }
    return chainConfigs[_chainId];
  }

  /**
   * @notice Get all supported chains
   */
  function getSupportedChains() external view override returns (uint16[] memory) {
    return supportedChains;
  }

  /**
   * @notice Get supported chains with pagination
   */
  function getSupportedChainsPaginated(
    uint256 offset,
    uint256 limit
  ) external view returns (uint16[] memory chains, bool hasMore) {
    uint256 totalChains = supportedChains.length;

    // Validate parameters
    if (offset >= totalChains) {
      return (new uint16[](0), false);
    }

    // Limit to maximum safe size
    if (limit > 50) {
      limit = 50;
    }

    uint256 remaining = totalChains - offset;
    uint256 returnSize = remaining < limit ? remaining : limit;

    chains = new uint16[](returnSize);
    for (uint256 i = 0; i < returnSize; i++) {
      chains[i] = supportedChains[offset + i];
    }

    hasMore = (offset + returnSize) < totalChains;
  }

  /**
   * @notice Get current chain ID
   */
  function getCurrentChainId() external view override returns (uint16) {
    return currentChainId;
  }

  /**
   * @notice Check if chain is supported
   */
  function isChainSupported(uint16 _chainId) external view override returns (bool) {
    return chainConfigs[_chainId].chainId == _chainId && chainConfigs[_chainId].isActive;
  }

  /**
   * @notice Calculate deterministic omniDRAGON address
   */
  function calculateOmniDragonAddress(
    address _deployer,
    bytes32 _salt,
    bytes32 _bytecodeHash
  ) external pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), _deployer, _salt, _bytecodeHash)))));
  }

  /**
   * @notice Configure LayerZero Send Library for an OApp
   */
  function configureSendLibrary(address _oapp, uint32 _eid, address _sendLib) external onlyOwner {
    require(_oapp != address(0), "Invalid OApp address");
    require(_sendLib != address(0), "Invalid send library address");

    // Get the LayerZero endpoint for current chain
    address endpoint = layerZeroEndpoints[currentChainId];
    require(endpoint != address(0), "No endpoint configured");

    // Prepare the call data for setSendLibrary
    bytes memory callData = abi.encodeWithSignature("setSendLibrary(address,uint32,address)", _oapp, _eid, _sendLib);

    // Make the call to the LayerZero endpoint
    (bool success, bytes memory returnData) = endpoint.call(callData);

    if (!success) {
      // If call failed, revert with the error
      if (returnData.length > 0) {
        assembly {
          revert(add(returnData, 32), mload(returnData))
        }
      } else {
        revert("LayerZero setSendLibrary failed");
      }
    }

    emit LayerZeroLibrarySet(_oapp, _eid, _sendLib, "Send");
  }

  /**
   * @notice Configure LayerZero Receive Library for an OApp
   */
  function configureReceiveLibrary(
    address _oapp,
    uint32 _eid,
    address _receiveLib,
    uint256 _gracePeriod
  ) external onlyOwner {
    require(_oapp != address(0), "Invalid OApp address");
    require(_receiveLib != address(0), "Invalid receive library address");

    // Get the LayerZero endpoint for current chain
    address endpoint = layerZeroEndpoints[currentChainId];
    require(endpoint != address(0), "No endpoint configured");

    // Prepare the call data for setReceiveLibrary
    bytes memory callData = abi.encodeWithSignature(
      "setReceiveLibrary(address,uint32,address,uint256)",
      _oapp,
      _eid,
      _receiveLib,
      _gracePeriod
    );

    // Make the call to the LayerZero endpoint
    (bool success, bytes memory returnData) = endpoint.call(callData);

    if (!success) {
      // If call failed, revert with the error
      if (returnData.length > 0) {
        assembly {
          revert(add(returnData, 32), mload(returnData))
        }
      } else {
        revert("LayerZero setReceiveLibrary failed");
      }
    }

    emit LayerZeroLibrarySet(_oapp, _eid, _receiveLib, "Receive");
  }

  /**
   * @notice Configure LayerZero ULN Config (DVN settings) for an OApp
   */
  function configureULNConfig(
    address _oapp,
    address _lib,
    uint32 _eid,
    uint64 _confirmations,
    address[] calldata _requiredDVNs,
    address[] calldata _optionalDVNs,
    uint8 _optionalDVNsThreshold
  ) external onlyOwner {
    require(_oapp != address(0), "Invalid OApp address");
    require(_lib != address(0), "Invalid library address");
    require(_requiredDVNs.length > 0, "At least one required DVN needed");

    // Get the LayerZero endpoint for current chain
    address endpoint = layerZeroEndpoints[currentChainId];
    require(endpoint != address(0), "No endpoint configured");

    // Encode ULN config for LayerZero V2
    bytes memory ulnConfig = abi.encode(_confirmations, _requiredDVNs, _optionalDVNs, _optionalDVNsThreshold);

    // Use correct LayerZero V2 signature: setConfig(address oapp, address lib, SetConfigParam[] params)
    SetConfigParam[] memory params = new SetConfigParam[](1);
    params[0] = SetConfigParam({
      eid: _eid,
      configType: 2, // ULN_CONFIG_TYPE
      config: ulnConfig
    });

    bytes memory callData = abi.encodeWithSignature(
      "setConfig(address,address,(uint32,uint32,bytes)[])",
      _oapp, // OApp address
      _lib, // Library address
      params // SetConfigParam[] array
    );

    // Make the call to the LayerZero endpoint
    (bool success, bytes memory returnData) = endpoint.call(callData);

    if (!success) {
      // If call failed, revert with the error
      if (returnData.length > 0) {
        assembly {
          revert(add(returnData, 32), mload(returnData))
        }
      } else {
        revert("LayerZero setConfig failed");
      }
    }

    emit LayerZeroConfigured(_oapp, _eid, "ULN_CONFIG");
  }

  /**
   * @notice Batch configure LayerZero settings for an OApp
   */
  function batchConfigureLayerZero(
    address _oapp,
    uint32 _eid,
    address _sendLib,
    address _receiveLib,
    uint64 _confirmations,
    address[] calldata _requiredDVNs
  ) external onlyOwner {
    // Configure Send Library
    this.configureSendLibrary(_oapp, _eid, _sendLib);

    // Configure Receive Library
    this.configureReceiveLibrary(_oapp, _eid, _receiveLib, 0);

    // Configure ULN Config for Send
    address[] memory emptyOptional = new address[](0);
    this.configureULNConfig(_oapp, _sendLib, _eid, _confirmations, _requiredDVNs, emptyOptional, 0);

    // Configure ULN Config for Receive
    this.configureULNConfig(_oapp, _receiveLib, _eid, _confirmations, _requiredDVNs, emptyOptional, 0);

    emit LayerZeroConfigured(_oapp, _eid, "BATCH_CONFIG");
  }

  /**
   * @notice Set chain ID to EID mapping
   */
  function setChainIdToEid(uint256 _chainId, uint32 _eid) external onlyOwner {
    chainIdToEid[_chainId] = _eid;
    eidToChainId[_eid] = _chainId;
  }

  /**
   * @notice Set LayerZero endpoint for a chain
   */
  function setLayerZeroEndpoint(uint16 _chainId, address _endpoint) external onlyOwner {
    if (_endpoint == address(0)) revert ZeroAddress();
    layerZeroEndpoints[_chainId] = _endpoint;
  }

  /**
   * @notice Get LayerZero endpoint for a chain
   */
  function getLayerZeroEndpoint(uint16 _chainId) external view returns (address) {
    return layerZeroEndpoints[_chainId];
  }

  /**
   * @notice Get wrapped native token for a chain
   */
  function getWrappedNativeToken(uint16 _chainId) external view override returns (address) {
    return chainConfigs[_chainId].wrappedNativeToken;
  }

  /**
   * @notice Get wrapped native token symbol for a chain
   */
  function getWrappedNativeSymbol(uint16 _chainId) external view override returns (string memory) {
    return chainConfigs[_chainId].wrappedNativeSymbol;
  }

  /**
   * @notice Get Uniswap V2 router for a chain
   */
  function getUniswapV2Router(uint16 _chainId) external view override returns (address) {
    return chainConfigs[_chainId].uniswapV2Router;
  }

  /**
   * @notice Get Uniswap V2 factory for a chain
   */
  function getUniswapV2Factory(uint16 _chainId) external view override returns (address) {
    return chainConfigs[_chainId].uniswapV2Factory;
  }

  /**
   * @notice Configure omniDRAGON peer connections
   * @param _oapp The omniDRAGON contract address
   * @param _eid Destination endpoint ID
   * @param _peer Peer contract address as bytes32
   */
  function configureOmniDragonPeer(address _oapp, uint32 _eid, bytes32 _peer) external onlyOwner {
    require(_oapp != address(0), "Invalid OApp address");
    require(_peer != bytes32(0), "Invalid peer address");

    // Prepare the call data for setPeer
    bytes memory callData = abi.encodeWithSignature("setPeer(uint32,bytes32)", _eid, _peer);

    // Make the call to the omniDRAGON contract as the owner
    (bool success, bytes memory returnData) = _oapp.call(callData);

    if (!success) {
      // If call failed, revert with the error
      if (returnData.length > 0) {
        assembly {
          revert(add(returnData, 32), mload(returnData))
        }
      } else {
        revert("omniDRAGON setPeer failed");
      }
    }

    emit LayerZeroConfigured(_oapp, _eid, "PEER_SET");
  }

  /**
   * @notice Configure omniDRAGON enforced options for cross-chain communication
   * @param _oapp The omniDRAGON contract address
   * @param _enforcedOptions Array of enforced options
   */
  function configureOmniDragonEnforcedOptions(address _oapp, bytes[] calldata _enforcedOptions) external onlyOwner {
    require(_oapp != address(0), "Invalid OApp address");
    require(_enforcedOptions.length > 0, "No enforced options provided");

    // Prepare the call data for setEnforcedOptions
    bytes memory callData = abi.encodeWithSignature("setEnforcedOptions((uint32,uint16,bytes)[])", _enforcedOptions);

    // Make the call to the omniDRAGON contract as the owner
    (bool success, bytes memory returnData) = _oapp.call(callData);

    if (!success) {
      // If call failed, revert with the error
      if (returnData.length > 0) {
        assembly {
          revert(add(returnData, 32), mload(returnData))
        }
      } else {
        revert("omniDRAGON setEnforcedOptions failed");
      }
    }

    emit LayerZeroConfigured(_oapp, 0, "ENFORCED_OPTIONS_SET");
  }

  /**
   * @notice Transfer ownership of an owned contract to a new owner
   * @param _contract The contract address to transfer ownership of
   * @param _newOwner The new owner address
   */
  function transferContractOwnership(address _contract, address _newOwner) external onlyOwner {
    require(_contract != address(0), "Invalid contract address");
    require(_newOwner != address(0), "Invalid new owner address");

    // Prepare the call data for transferOwnership
    bytes memory callData = abi.encodeWithSignature("transferOwnership(address)", _newOwner);

    // Make the call to the contract
    (bool success, bytes memory returnData) = _contract.call(callData);

    if (!success) {
      // If call failed, revert with the error
      if (returnData.length > 0) {
        assembly {
          revert(add(returnData, 32), mload(returnData))
        }
      } else {
        revert("transferOwnership failed");
      }
    }
  }

  // ============ ORACLE MANAGEMENT ============

  // Oracle configuration storage
  mapping(uint16 => address) public priceOracles; // chainId => oracle address
  mapping(uint16 => IOmniDragonRegistry.OracleConfig) public oracleConfigs;

  // Primary oracle configuration
  address public primaryOracle;
  uint32 public primaryChainEid;

  // Events for oracle management are already defined in the interface

  /**
   * @notice Set price oracle for a specific chain
   * @param _chainId Chain ID
   * @param _oracle Oracle address
   */
  function setPriceOracle(uint16 _chainId, address _oracle) external onlyOwner {
    require(_oracle != address(0), "Invalid oracle address");
    
    priceOracles[_chainId] = _oracle;
    oracleConfigs[_chainId].isConfigured = true;
    
    emit PriceOracleSet(_chainId, _oracle);
  }

  /**
   * @notice Get price oracle for a specific chain
   * @param _chainId Chain ID
   * @return Oracle address
   */
  function getPriceOracle(uint16 _chainId) external view returns (address) {
    return priceOracles[_chainId];
  }

  /**
   * @notice Configure primary oracle (on Sonic chain)
   * @param _primaryOracle Primary oracle address
   * @param _chainEid Primary chain EID
   */
  function configurePrimaryOracle(address _primaryOracle, uint32 _chainEid) external onlyOwner {
    require(_primaryOracle != address(0), "Invalid oracle address");
    
    primaryOracle = _primaryOracle;
    primaryChainEid = _chainEid;
    
    // Set as oracle for Sonic chain (146)
    priceOracles[146] = _primaryOracle;
    oracleConfigs[146].primaryOracle = _primaryOracle;
    oracleConfigs[146].primaryChainEid = _chainEid;
    oracleConfigs[146].isConfigured = true;
    
    emit PrimaryOracleConfigured(_primaryOracle, _chainEid);
  }

  /**
   * @notice Set lzRead channel for a chain
   * @param _chainId Chain ID
   * @param _channelId lzRead channel ID
   */
  function setLzReadChannel(uint16 _chainId, uint32 _channelId) external onlyOwner {
    oracleConfigs[_chainId].lzReadChannelId = _channelId;
    emit LzReadChannelConfigured(_chainId, _channelId);
  }

  /**
   * @notice Get oracle configuration for a chain
   * @param _chainId Chain ID
   * @return Oracle configuration
   */
  function getOracleConfig(uint16 _chainId) external view returns (IOmniDragonRegistry.OracleConfig memory) {
    return oracleConfigs[_chainId];
  }
} 