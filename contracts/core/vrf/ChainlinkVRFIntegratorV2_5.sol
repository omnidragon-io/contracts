// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ChainlinkVRFIntegratorV2_5 - OmniDragon Cross-Chain VRF System
 * @author 0xakita.eth
 * @dev Sonic-based contract that receives random words requests and forwards them to Arbitrum
 *      for Chainlink VRF 2.5 processing. Part of the OmniDragon ecosystem's cross-chain lottery
 *      and random words infrastructure.
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OApp, MessagingFee, Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import {OAppOptionsType3} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {IOmniDragonRegistry} from "../../interfaces/config/IOmniDragonRegistry.sol";

// Import the standard VRF callback interface
import "../../interfaces/vrf/IRandomWordsCallbackV2_5.sol";

/**
 * @title ChainlinkVRFIntegratorV2_5
 * @notice Resides on Sonic. Called by a provider to get random words from a peer on Arbitrum.
 */
contract ChainlinkVRFIntegratorV2_5 is OApp, OAppOptionsType3 {
  using OptionsBuilder for bytes;
  
  IOmniDragonRegistry public immutable registry;

  // Constants
  uint32 constant ARBITRUM_EID = 30110;

  // State variables
  uint64 public requestCounter;
  uint32 public defaultGasLimit = 690420; // Updated default gas limit

  // Request tracking
  struct RequestStatus {
    bool fulfilled;
    bool exists;
    address provider;
    uint256 randomWord;
    uint256 timestamp;
    bool isContract; // Track if provider is a contract
  }
  mapping(uint64 => RequestStatus) public s_requests;
  mapping(uint64 => address) public randomWordsProviders;

  // Events
  event RandomWordsRequested(uint64 indexed requestId, address indexed requester, uint32 dstEid);
  event MessageSent(uint64 indexed requestId, uint32 indexed dstEid, bytes message);
  event RandomWordsReceived(uint256[] randomWords, uint64 indexed sequence, address indexed provider);
  event CallbackFailed(uint64 indexed sequence, address indexed provider, string reason);
  event CallbackSucceeded(uint64 indexed sequence, address indexed provider);
  event RequestExpired(uint64 indexed sequence, address indexed provider);
  event GasLimitUpdated(uint32 oldLimit, uint32 newLimit);
  event FeeMRegistered(address indexed contractAddress, uint256 indexed feeId);

  // Configuration
  uint256 public requestTimeout = 1 hours; // Requests expire after 1 hour

  constructor(address _registry) OApp(IOmniDragonRegistry(_registry).getLayerZeroEndpoint(uint16(block.chainid)), msg.sender) Ownable(msg.sender) {
    registry = IOmniDragonRegistry(_registry);
  }

  /**
   * @dev Receives random words responses from Arbitrum
   * Updated to handle the correct payload format: (sequence, randomWord)
   */
  function _lzReceive(
    Origin calldata _origin,
    bytes32,
    bytes calldata _payload,
    address,
    bytes calldata
  ) internal override {
    require(peers[_origin.srcEid] == _origin.sender, "Unauthorized");
    require(_payload.length == 64, "Invalid payload size");

    (uint64 sequence, uint256 randomWord) = abi.decode(_payload, (uint64, uint256));

    RequestStatus storage request = s_requests[sequence];
    require(request.exists, "Request not found");
    require(!request.fulfilled, "Request already fulfilled");
    require(block.timestamp <= request.timestamp + requestTimeout, "Request expired");

    address provider = request.provider;
    require(provider != address(0), "Provider not found");

    // Mark as fulfilled
    request.fulfilled = true;
    request.randomWord = randomWord;

    // Clean up provider mapping
    delete randomWordsProviders[sequence];

    // Create randomWords array for callback/event
    uint256[] memory randomWords = new uint256[](1);
    randomWords[0] = randomWord;

    // Always emit the RandomWordsReceived event first
    emit RandomWordsReceived(randomWords, sequence, provider);

    // Only attempt callback if provider is a contract
    if (request.isContract) {
      try IRandomWordsCallbackV2_5(provider).receiveRandomWords(randomWords, uint256(sequence)) {
        emit CallbackSucceeded(sequence, provider);
      } catch Error(string memory reason) {
        emit CallbackFailed(sequence, provider, reason);
      } catch (bytes memory /*lowLevelData*/) {
        emit CallbackFailed(sequence, provider, "Low-level callback failure");
      }
    }
    // For EOA (wallet) requests, the RandomWordsReceived event is sufficient
    // Users can query s_requests[sequence].randomWord to get their value
  }

  /**
   * @notice Manual retry for stuck LayerZero messages
   * @dev In LayerZero V2, retry is handled by the executor infrastructure
   *      This function is for administrative purposes and monitoring
   * @param requestId The request ID that may need attention
   */
  function checkRequestStatus(
    uint64 requestId
  )
    external
    view
    returns (bool fulfilled, bool exists, address provider, uint256 randomWord, uint256 timestamp, bool expired)
  {
    RequestStatus memory request = s_requests[requestId];
    return (
      request.fulfilled,
      request.exists,
      request.provider,
      request.randomWord,
      request.timestamp,
      block.timestamp > request.timestamp + requestTimeout
    );
  }

  /**
   * @notice Get the random word for a fulfilled request
   * @param requestId The request ID to query
   * @return randomWord The random word (0 if not fulfilled)
   * @return fulfilled Whether the request has been fulfilled
   */
  function getRandomWord(uint64 requestId) external view returns (uint256 randomWord, bool fulfilled) {
    RequestStatus memory request = s_requests[requestId];
    return (request.randomWord, request.fulfilled);
  }

  /**
   * @notice Quote fee using the default options
   */
  function quoteFee() public view returns (MessagingFee memory fee) {
    bytes memory options = hex"000301001101000000000000000000000000000A88F4"; // default executor gas
    bytes memory payload = abi.encode(uint64(requestCounter + 1));
    return _quote(ARBITRUM_EID, payload, options, false);
  }

  /**
   * @dev Request random words with custom gas limit
   * @param _gasLimit Custom gas limit for the cross-chain execution
   */
  /**
   * @notice Quote fee with a custom gas limit
   */
  function quoteFeeWithGas(uint32 _gasLimit) public view returns (MessagingFee memory fee) {
    bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(_gasLimit, 0);
    bytes memory payload = abi.encode(uint64(requestCounter + 1));
    return _quote(ARBITRUM_EID, payload, options, false);
  }

  /**
   * @notice Request random words (integrator-sponsored fee, default gas)
   */
  function requestRandomWords(uint32 dstEid)
    public
    returns (MessagingReceipt memory receipt, uint64 requestId)
  {
    require(dstEid == ARBITRUM_EID, "Invalid destination EID");
    bytes memory options = hex"000301001101000000000000000000000000000A88F4";

    bytes32 peer = peers[ARBITRUM_EID];
    require(peer != bytes32(0), "Arbitrum peer not set");

    requestCounter++;
    requestId = requestCounter;

    bool isContract = msg.sender.code.length > 0;
    s_requests[requestId] = RequestStatus({
      fulfilled: false,
      exists: true,
      provider: msg.sender,
      randomWord: 0,
      timestamp: block.timestamp,
      isContract: isContract
    });
    randomWordsProviders[requestId] = msg.sender;

    bytes memory payload = abi.encode(requestId);
    MessagingFee memory fee = quoteFee();
    require(address(this).balance >= fee.nativeFee, "NotEnoughNative");

    receipt = _lzSend(
      ARBITRUM_EID,
      payload,
      options,
      fee,
      payable(address(this))
    );

    emit RandomWordsRequested(requestId, msg.sender, ARBITRUM_EID);
    emit MessageSent(requestId, ARBITRUM_EID, payload);
  }

  // Custom gas requests can be achieved by updating defaultGasLimit via setDefaultGasLimit

  // (Old quote* and request*Simple functions removed in favor of the professional API)

  /**
   * @notice Request random words with caller-provided ETH for LayerZero fees
   * @param dstEid Destination endpoint ID (should be ARBITRUM_EID)
   * @return receipt LayerZero messaging receipt
   * @return requestId VRF request ID
   */
  function requestRandomWordsPayable(uint32 dstEid)
    external
    payable
    returns (MessagingReceipt memory receipt, uint64 requestId)
  {
    require(dstEid == ARBITRUM_EID, "Invalid destination EID");
    bytes memory options = hex"000301001101000000000000000000000000000A88F4";

    bytes32 peer = peers[ARBITRUM_EID];
    require(peer != bytes32(0), "Arbitrum peer not set");

    requestCounter++;
    requestId = requestCounter;

    bool isContract = msg.sender.code.length > 0;
    s_requests[requestId] = RequestStatus({
      fulfilled: false,
      exists: true,
      provider: msg.sender,
      randomWord: 0,
      timestamp: block.timestamp,
      isContract: isContract
    });
    randomWordsProviders[requestId] = msg.sender;

    bytes memory payload = abi.encode(requestId);
    MessagingFee memory fee = quoteFee();
    require(msg.value >= fee.nativeFee, "Insufficient fee provided");

    receipt = _lzSend(
      ARBITRUM_EID,
      payload,
      options,
      fee,
      payable(msg.sender) // Return excess to caller
    );

    emit RandomWordsRequested(requestId, msg.sender, ARBITRUM_EID);
    emit MessageSent(requestId, ARBITRUM_EID, payload);

    return (receipt, requestId);
  }

  /**
   * @dev Update default gas limit (owner only)
   */
  function setDefaultGasLimit(uint32 _gasLimit) external onlyOwner {
    uint32 oldLimit = defaultGasLimit;
    defaultGasLimit = _gasLimit;
    emit GasLimitUpdated(oldLimit, _gasLimit);
  }

  /**
   * @dev Update request timeout (owner only)
   */
  function setRequestTimeout(uint256 _timeout) external onlyOwner {
    requestTimeout = _timeout;
  }

  /**
   * @dev Clean up expired requests (anyone can call)
   * @param requestIds Array of request IDs to clean up
   */
  function cleanupExpiredRequests(uint64[] calldata requestIds) external {
    for (uint256 i = 0; i < requestIds.length; i++) {
      uint64 requestId = requestIds[i];
      RequestStatus storage request = s_requests[requestId];

      if (request.exists && !request.fulfilled && block.timestamp > request.timestamp + requestTimeout) {
        address provider = request.provider;

        // Mark as expired and clean up
        delete s_requests[requestId];
        delete randomWordsProviders[requestId];

        emit RequestExpired(requestId, provider);
      }
    }
  }

  /**
   * @dev Override _payNative to allow paying LayerZero fees from contract balance
   * When msg.value is 0 (standard for this integrator), use the contract balance
   * to cover the native fee required by the LayerZero Endpoint.
   */
  function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
    if (msg.value == 0) {
      require(address(this).balance >= _nativeFee, "NotEnoughNative");
      return _nativeFee;
    }

    // If a caller sends value, enforce exact payment semantics expected by OApp
    if (msg.value != _nativeFee) revert NotEnoughNative(msg.value);
    return _nativeFee;
  }

  /**
   * @dev Register my contract on Sonic FeeM
   * @notice This function registers the contract with Sonic's fee management system
   */
  function registerMe() external {
    (bool _success, ) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
      abi.encodeWithSignature("selfRegister(uint256)", 143)
    );
    require(_success, "FeeM registration failed");
    emit FeeMRegistered(address(this), 143);
  }

  /**
   * @dev Emergency withdraw (owner only)
   */
  function withdraw() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  /**
   * @dev Receive ETH
   */
  receive() external payable {}
}