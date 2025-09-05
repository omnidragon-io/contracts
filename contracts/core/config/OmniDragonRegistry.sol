// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/config/IOmniDragonRegistry.sol";

//
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
  // Chain configuration
  mapping(uint16 => IOmniDragonRegistry.ChainConfig) private chainConfigs;
  uint16[] private supportedChains;
  uint16 private currentChainId;
  uint256 public constant MAX_SUPPORTED_CHAINS = 50;

  // LayerZero endpoints and mapping
  mapping(uint256 => uint32) public chainIdToEid;
  mapping(uint32 => uint256) public eidToChainId;
  mapping(uint16 => address) public layerZeroEndpoints;
  address public immutable layerZeroCommonEndpoint;

  // Oracles
  mapping(uint16 => address) public priceOracles;
  mapping(uint16 => IOmniDragonRegistry.OracleConfig) public oracleConfigs;
  address public primaryOracle;
  uint32 public primaryChainEid;
  mapping(uint16 => address) public secondaryOracles;

  // Events
  event CurrentChainSet(uint16 indexed chainId);
  event LayerZeroConfigured(address indexed oapp, uint32 indexed eid, string configType);
  event LayerZeroLibrarySet(address indexed oapp, uint32 indexed eid, address lib, string libraryType);
  event LayerZeroEndpointUpdated(uint16 indexed chainId, address endpoint);
  event WrappedNativeSymbolUpdated(uint16 indexed chainId, string symbol);
  event ChainIdToEidUpdated(uint256 chainId, uint32 eid);
  event SecondaryOracleSet(uint16 indexed chainId, address indexed oracle);

  // Errors
  error ChainAlreadyRegistered(uint16 chainId);
  error ChainNotRegistered(uint16 chainId);
  error ZeroAddress();
  error TooManyChains();

  struct SetConfigParam { uint32 eid; uint32 configType; bytes config; }

  constructor(address _initialOwner) Ownable(_initialOwner) {
    currentChainId = uint16(block.chainid);
    layerZeroCommonEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;
    layerZeroEndpoints[146] = layerZeroCommonEndpoint;
    layerZeroEndpoints[42161] = layerZeroCommonEndpoint;
    layerZeroEndpoints[43114] = layerZeroCommonEndpoint;
  }

  // Internal
  function _getDefaultWrappedNativeSymbol(uint256 _chainId) internal pure returns (string memory) {
    if (_chainId == 146) return "WS";
    if (_chainId == 43114) return "WAVAX";
    if (_chainId == 250) return "WFTM";
    if (_chainId == 137) return "WMATIC";
    if (_chainId == 56) return "WBNB";
    if (_chainId == 239) return "WTAC";
    if (_chainId == 999) return "HYPE";
    return "WETH";
  }

  // Chain config
  function setCurrentChainId(uint16 _chainId) external onlyOwner { currentChainId = _chainId; emit CurrentChainSet(_chainId); }

  function registerChain(
    uint16 _chainId, string calldata _chainName, address _wrappedNativeToken, address _uniswapV2Router, address _uniswapV2Factory, bool _isActive
  ) external override onlyOwner {
    if (chainConfigs[_chainId].chainId == _chainId) revert ChainAlreadyRegistered(_chainId);
    if (supportedChains.length >= MAX_SUPPORTED_CHAINS) revert TooManyChains();
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
    emit ChainRegistered(_chainId, _chainName);
  }

  function updateChain(uint16 _chainId, string calldata _chainName, address _wrappedNativeToken, address _uniswapV2Router, address _uniswapV2Factory) external override onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId);
    chainConfigs[_chainId].chainName = _chainName;
    chainConfigs[_chainId].wrappedNativeToken = _wrappedNativeToken;
    chainConfigs[_chainId].wrappedNativeSymbol = _getDefaultWrappedNativeSymbol(_chainId);
    chainConfigs[_chainId].uniswapV2Router = _uniswapV2Router;
    chainConfigs[_chainId].uniswapV2Factory = _uniswapV2Factory;
    emit ChainUpdated(_chainId);
  }

  function updateWrappedNativeSymbol(uint16 _chainId, string calldata _symbol) external onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId);
    chainConfigs[_chainId].wrappedNativeSymbol = _symbol; emit WrappedNativeSymbolUpdated(_chainId, _symbol); emit ChainUpdated(_chainId);
  }

  function setChainStatus(uint16 _chainId, bool _isActive) external override onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId);
    chainConfigs[_chainId].isActive = _isActive; emit ChainStatusChanged(_chainId, _isActive);
  }

  function getChainConfig(uint16 _chainId) external view override returns (IOmniDragonRegistry.ChainConfig memory) {
    if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId);
    return chainConfigs[_chainId];
  }

  function getSupportedChains() external view override returns (uint16[] memory) { return supportedChains; }
  function getCurrentChainId() external view override returns (uint16) { return currentChainId; }
  function isChainSupported(uint16 _chainId) external view override returns (bool) { return chainConfigs[_chainId].isActive && chainConfigs[_chainId].chainId == _chainId; }

  // Endpoints and mapping
  function setChainIdToEid(uint256 _chainId, uint32 _eid) external onlyOwner { chainIdToEid[_chainId] = _eid; eidToChainId[_eid] = _chainId; emit ChainIdToEidUpdated(_chainId, _eid); }
  function setLayerZeroEndpoint(uint16 _chainId, address _endpoint) external onlyOwner { if (_endpoint == address(0)) revert ZeroAddress(); layerZeroEndpoints[_chainId] = _endpoint; emit LayerZeroEndpointUpdated(_chainId, _endpoint); }
  function getLayerZeroEndpoint(uint16 _chainId) external view returns (address) {
    address ep = layerZeroEndpoints[_chainId];
    return ep == address(0) ? layerZeroCommonEndpoint : ep;
  }

  // Lookups
  function getWrappedNativeToken(uint16 _chainId) external view override returns (address) { return chainConfigs[_chainId].wrappedNativeToken; }
  function getWrappedNativeSymbol(uint16 _chainId) external view override returns (string memory) { return chainConfigs[_chainId].wrappedNativeSymbol; }
  function getUniswapV2Router(uint16 _chainId) external view override returns (address) { return chainConfigs[_chainId].uniswapV2Router; }
  function getUniswapV2Factory(uint16 _chainId) external view override returns (address) { return chainConfigs[_chainId].uniswapV2Factory; }

  // Oracle management
  function setPriceOracle(uint16 _chainId, address _oracle) external override onlyOwner { require(_oracle != address(0), "Invalid oracle address"); priceOracles[_chainId] = _oracle; oracleConfigs[_chainId].isConfigured = true; emit PriceOracleSet(_chainId, _oracle); }
  function getPriceOracle(uint16 _chainId) external view returns (address) { return priceOracles[_chainId]; }
  function setSecondaryOracle(uint16 _chainId, address _oracle) external onlyOwner { require(_oracle != address(0), "Invalid oracle address"); secondaryOracles[_chainId] = _oracle; emit SecondaryOracleSet(_chainId, _oracle); }
  function getSecondaryOracle(uint16 _chainId) external view returns (address) { return secondaryOracles[_chainId]; }
  function configurePrimaryOracle(address _primaryOracle, uint32 _chainEid) external override onlyOwner { require(_primaryOracle != address(0), "Invalid oracle address"); primaryOracle = _primaryOracle; primaryChainEid = _chainEid; priceOracles[146] = _primaryOracle; oracleConfigs[146].primaryOracle = _primaryOracle; oracleConfigs[146].primaryChainEid = _chainEid; oracleConfigs[146].isConfigured = true; emit PrimaryOracleConfigured(_primaryOracle, _chainEid); }
  function setLzReadChannel(uint16 _chainId, uint32 _channelId) external override onlyOwner { oracleConfigs[_chainId].lzReadChannelId = _channelId; emit LzReadChannelConfigured(_chainId, _channelId); }
  function getOracleConfigByChainId(uint256 _chainId) external view returns (IOmniDragonRegistry.OracleConfig memory) {
    return oracleConfigs[uint16(_chainId)];
  }
  function getOracleConfig(uint16 _chainId) external view returns (IOmniDragonRegistry.OracleConfig memory) {
    return oracleConfigs[_chainId];
  }

  // LZ helpers
  function _executeLowLevelCall(address target, bytes memory callData, string memory errorMessage) private {
    (bool success, bytes memory returnData) = target.call(callData);
    if (!success) { if (returnData.length > 0) { assembly { revert(add(returnData, 32), mload(returnData)) } } else { revert(errorMessage); } }
  }
  function configureSendLibrary(address _oapp, uint32 _eid, address _sendLib) external onlyOwner { require(_oapp!=address(0)&&_sendLib!=address(0),"bad"); address ep=layerZeroEndpoints[currentChainId]; require(ep!=address(0),"no ep"); bytes memory cd=abi.encodeWithSignature("setSendLibrary(address,uint32,address)",_oapp,_eid,_sendLib); _executeLowLevelCall(ep,cd,"lz setSendLibrary fail"); emit LayerZeroLibrarySet(_oapp,_eid,_sendLib,"Send"); }
  function configureReceiveLibrary(address _oapp, uint32 _eid, address _receiveLib, uint256 _grace) external onlyOwner { require(_oapp!=address(0)&&_receiveLib!=address(0),"bad"); address ep=layerZeroEndpoints[currentChainId]; require(ep!=address(0),"no ep"); bytes memory cd=abi.encodeWithSignature("setReceiveLibrary(address,uint32,address,uint256)",_oapp,_eid,_receiveLib,_grace); _executeLowLevelCall(ep,cd,"lz setReceiveLibrary fail"); emit LayerZeroLibrarySet(_oapp,_eid,_receiveLib,"Receive"); }
  function configureULNConfig(address _oapp, address _lib, uint32 _eid, uint64 _conf, address[] calldata _req, address[] calldata _opt, uint8 _optTh) external onlyOwner {
    require(_oapp != address(0) && _lib != address(0) && _req.length > 0, "bad");
    address ep = layerZeroEndpoints[currentChainId];
    require(ep != address(0), "no ep");
    // ULN V302 expects: (uint64 confirmations, uint8 requiredDVNCount, uint8 optionalDVNCount, uint8 optionalDVNThreshold, address[] requiredDVNs, address[] optionalDVNs)
    bytes memory cfg = abi.encode(_conf, uint8(_req.length), uint8(_opt.length), _optTh, _req, _opt);
    SetConfigParam[] memory params = new SetConfigParam[](1);
    params[0] = SetConfigParam({ eid: _eid, configType: 2, config: cfg });
    bytes memory cd = abi.encodeWithSignature("setConfig(address,address,(uint32,uint32,bytes)[])", _oapp, _lib, params);
    _executeLowLevelCall(ep, cd, "lz setConfig fail");
    emit LayerZeroConfigured(_oapp, _eid, "ULN_CONFIG");
  }

  function configureExecutorConfig(address _oapp, address _lib, uint32 _eid, uint32 _maxMsgSize, address _executor) external onlyOwner {
    require(_oapp != address(0) && _lib != address(0) && _executor != address(0), "bad");
    address ep = layerZeroEndpoints[currentChainId];
    require(ep != address(0), "no ep");
    // ExecutorConfig: (uint32 maxMessageSize, address executor)
    bytes memory cfg = abi.encode(_maxMsgSize, _executor);
    SetConfigParam[] memory params = new SetConfigParam[](1);
    params[0] = SetConfigParam({ eid: _eid, configType: 1, config: cfg });
    bytes memory cd = abi.encodeWithSignature("setConfig(address,address,(uint32,uint32,bytes)[])", _oapp, _lib, params);
    _executeLowLevelCall(ep, cd, "lz setConfig fail");
    emit LayerZeroConfigured(_oapp, _eid, "EXECUTOR_CONFIG");
  }
  function batchConfigureLayerZero(address _oapp,uint32 _eid,address _sendLib,address _recvLib,uint64 _conf,address[] calldata _req) external onlyOwner { this.configureSendLibrary(_oapp,_eid,_sendLib); this.configureReceiveLibrary(_oapp,_eid,_recvLib,0); address[] memory empty=new address[](0); this.configureULNConfig(_oapp,_sendLib,_eid,_conf,_req,empty,0); this.configureULNConfig(_oapp,_recvLib,_eid,_conf,_req,empty,0); emit LayerZeroConfigured(_oapp,_eid,"BATCH_CONFIG"); }
  function configureOmniDragonPeer(address _oapp,uint32 _eid,bytes32 _peer) external onlyOwner { require(_oapp!=address(0)&&_peer!=bytes32(0),"bad"); bytes memory cd=abi.encodeWithSignature("setPeer(uint32,bytes32)",_eid,_peer); _executeLowLevelCall(_oapp,cd,"peer fail"); emit LayerZeroConfigured(_oapp,_eid,"PEER_SET"); }
  function configureOmniDragonEnforcedOptions(address _oapp, bytes[] calldata _opts) external onlyOwner { require(_oapp!=address(0)&&_opts.length>0,"bad"); bytes memory cd=abi.encodeWithSignature("setEnforcedOptions((uint32,uint16,bytes)[])",_opts); _executeLowLevelCall(_oapp,cd,"opts fail"); emit LayerZeroConfigured(_oapp,0,"ENFORCED_OPTIONS_SET"); }
  function transferContractOwnership(address _contract, address _newOwner) external onlyOwner { require(_contract!=address(0)&&_newOwner!=address(0),"bad"); bytes memory cd=abi.encodeWithSignature("transferOwnership(address)",_newOwner); _executeLowLevelCall(_contract,cd,"xfer owner fail"); }
}


