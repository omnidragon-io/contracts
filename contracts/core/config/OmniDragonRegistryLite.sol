// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OmniDragonRegistryLite
 * @dev Minimal registry to satisfy runtime reads (endpoints and DEX/WNATIVE per chain)
 */
contract OmniDragonRegistryLite is Ownable {
  struct ChainConfig { uint16 chainId; string chainName; address wrappedNativeToken; string wrappedNativeSymbol; address uniswapV2Router; address uniswapV2Factory; bool isActive; }

  mapping(uint16 => ChainConfig) private chainConfigs;
  uint16[] private supportedChains;
  uint16 private currentChainId;

  mapping(uint16 => address) public layerZeroEndpoints;

  event ChainRegistered(uint16 indexed chainId, string chainName);
  event ChainUpdated(uint16 indexed chainId);
  event ChainStatusChanged(uint16 indexed chainId, bool isActive);
  event CurrentChainSet(uint16 indexed chainId);
  event LayerZeroEndpointUpdated(uint16 indexed chainId, address endpoint);

  error ChainAlreadyRegistered(uint16 chainId);
  error ChainNotRegistered(uint16 chainId);
  error ZeroAddress();

  constructor(address _owner) Ownable(_owner) {
    currentChainId = uint16(block.chainid);
  }

  function setCurrentChainId(uint16 _chainId) external onlyOwner { currentChainId = _chainId; emit CurrentChainSet(_chainId); }

  function registerChain(uint16 _chainId, string calldata _chainName, address _wrappedNativeToken, address _router, address _factory, bool _isActive) external onlyOwner {
    if (chainConfigs[_chainId].chainId == _chainId) revert ChainAlreadyRegistered(_chainId);
    chainConfigs[_chainId] = ChainConfig({ chainId: _chainId, chainName: _chainName, wrappedNativeToken: _wrappedNativeToken, wrappedNativeSymbol: "", uniswapV2Router: _router, uniswapV2Factory: _factory, isActive: _isActive });
    supportedChains.push(_chainId);
    emit ChainRegistered(_chainId, _chainName);
  }

  function updateChain(uint16 _chainId, string calldata _chainName, address _wrappedNativeToken, address _router, address _factory) external onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId);
    ChainConfig storage c = chainConfigs[_chainId];
    c.chainName = _chainName; c.wrappedNativeToken = _wrappedNativeToken; c.uniswapV2Router = _router; c.uniswapV2Factory = _factory; emit ChainUpdated(_chainId);
  }

  function setWrappedNativeSymbol(uint16 _chainId, string calldata _symbol) external onlyOwner {
    if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId);
    chainConfigs[_chainId].wrappedNativeSymbol = _symbol; emit ChainUpdated(_chainId);
  }

  function setChainStatus(uint16 _chainId, bool _isActive) external onlyOwner { if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId); chainConfigs[_chainId].isActive = _isActive; emit ChainStatusChanged(_chainId, _isActive); }

  function getChainConfig(uint16 _chainId) external view returns (ChainConfig memory) { if (chainConfigs[_chainId].chainId != _chainId) revert ChainNotRegistered(_chainId); return chainConfigs[_chainId]; }
  function getSupportedChains() external view returns (uint16[] memory) { return supportedChains; }
  function getCurrentChainId() external view returns (uint16) { return currentChainId; }
  function isChainSupported(uint16 _chainId) external view returns (bool) { return chainConfigs[_chainId].isActive && chainConfigs[_chainId].chainId == _chainId; }

  function setLayerZeroEndpoint(uint16 _chainId, address _endpoint) external onlyOwner { if (_endpoint == address(0)) revert ZeroAddress(); layerZeroEndpoints[_chainId] = _endpoint; emit LayerZeroEndpointUpdated(_chainId, _endpoint); }
  function getLayerZeroEndpoint(uint16 _chainId) external view returns (address) { return layerZeroEndpoints[_chainId]; }

  function getWrappedNativeToken(uint16 _chainId) external view returns (address) { return chainConfigs[_chainId].wrappedNativeToken; }
  function getWrappedNativeSymbol(uint16 _chainId) external view returns (string memory) { return chainConfigs[_chainId].wrappedNativeSymbol; }
  function getUniswapV2Router(uint16 _chainId) external view returns (address) { return chainConfigs[_chainId].uniswapV2Router; }
  function getUniswapV2Factory(uint16 _chainId) external view returns (address) { return chainConfigs[_chainId].uniswapV2Factory; }
}


