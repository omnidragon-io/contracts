// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDragonJackpotVault} from "../../interfaces/lottery/IDragonJackpotVault.sol";

// Interface for wrapped native tokens (wETH/wS/etc)
interface IWrappedNativeToken {
  function deposit() external payable;
  function withdraw(uint256 amount) external;
  function transfer(address to, uint256 amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
}

import {DragonErrors} from "../../libraries/DragonErrors.sol";

/**
 * @title OmniDragonJackpotVault
 * @author 0xakita.eth
 * @dev Jackpot vault with lottery mechanics and fee management
 *
 * Central component for Dragon ecosystem lottery system and jackpot distribution
 * Integrates with OmniDragon token to provide engaging lottery experiences
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
contract OmniDragonJackpotVault is IDragonJackpotVault, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Constants for payout logic
  uint256 public constant WINNER_PERCENTAGE = 6900; // 69% to winner
  uint256 public constant ROLLOVER_PERCENTAGE = 3100; // 31% stays for next round  
  uint256 public constant BASIS_POINTS = 10000; // 100%

  // Core state
  mapping(address => uint256) public jackpotBalances;
  address public wrappedNativeToken;
  uint256 public lastWinTimestamp;

  // Events  
  event JackpotAdded(address indexed token, uint256 amount);
  event JackpotPaid(address indexed token, address indexed winner, uint256 winAmount, uint256 rolloverAmount);
  event WrappedNativeTokenSet(address indexed oldToken, address indexed newToken);
  event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

  /**
   * @dev Constructor
   * @param _wrappedNativeToken Initial wrapped native token address
   * @param _owner Owner address
   */
  constructor(address _wrappedNativeToken, address _owner) Ownable(_owner) {
    // Allow placeholder (zero) for vanity CREATE2 deployments across chains.
    // Runtime functions already enforce non-zero via DragonErrors.WrappedTokenNotSet().
    wrappedNativeToken = _wrappedNativeToken;
  }

  /**
   * @dev Post-deploy initializer to set wrapped native token once.
   */
  function initializeWrappedNativeToken(address _wrappedNativeToken) external onlyOwner {
    if (wrappedNativeToken != address(0)) revert DragonErrors.UnauthorizedCaller();
    if (_wrappedNativeToken == address(0)) revert DragonErrors.ZeroAddress();
    wrappedNativeToken = _wrappedNativeToken;
    emit WrappedNativeTokenSet(address(0), _wrappedNativeToken);
  }

  /**
   * @dev Add ERC20 tokens to the jackpot - gas optimized
   * @param token Token address
   * @param amount Amount to add
   */
  function addERC20ToJackpot(address token, uint256 amount) external {
    if (amount == 0) revert DragonErrors.ZeroAmount();
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    jackpotBalances[token] += amount;
    emit JackpotAdded(token, amount);
  }

  /**
   * @dev Add already collected funds to accounting (owner only)
   * @param token Token address 
   * @param amount Amount to add to accounting
   */
  function addCollectedFunds(address token, uint256 amount) external onlyOwner {
    if (amount == 0) revert DragonErrors.ZeroAmount();
    if (token == address(0)) revert DragonErrors.ZeroAddress();
    jackpotBalances[token] += amount;
    emit JackpotAdded(token, amount);
  }

  /**
   * @dev Get the current jackpot balance (in wrapped native token)
   * @return balance The current jackpot balance
   */
  function getJackpotBalance() external view override returns (uint256 balance) {
    return jackpotBalances[wrappedNativeToken];
  }

  /**
   * @dev Pay jackpot to winner - 69% to winner, 31% rolls over
   * @param winner Winner address who gets 69% of the jackpot
   */
  function payEntireJackpot(address winner) external override onlyOwner nonReentrant {
    if (wrappedNativeToken == address(0)) revert DragonErrors.WrappedTokenNotSet();
    if (winner == address(0)) revert DragonErrors.ZeroAddress();
    
    uint256 totalJackpot = jackpotBalances[wrappedNativeToken];
    if (totalJackpot == 0) revert DragonErrors.NoJackpotToPay();

    // Calculate payouts: 69% to winner, 31% stays for next round
    uint256 winnerAmount = (totalJackpot * WINNER_PERCENTAGE) / BASIS_POINTS;
    uint256 rolloverAmount = totalJackpot - winnerAmount; // Remainder stays

    // Update state - only reduce by winner amount, rollover stays
    jackpotBalances[wrappedNativeToken] = rolloverAmount;
    lastWinTimestamp = block.timestamp;

    // Pay winner their 69%
    IERC20(wrappedNativeToken).safeTransfer(winner, winnerAmount);
    emit JackpotPaid(wrappedNativeToken, winner, winnerAmount, rolloverAmount);
  }

  /**
   * @dev Pay jackpot with specific token - 69% to winner, 31% rolls over
   * @param token Token address
   * @param winner Winner address who gets 69% of the jackpot
   */
  function payEntireJackpotWithToken(address token, address winner) external onlyOwner nonReentrant {
    if (winner == address(0)) revert DragonErrors.ZeroAddress();
    if (token == address(0)) revert DragonErrors.ZeroAddress();
    
    uint256 totalJackpot = jackpotBalances[token];
    if (totalJackpot == 0) revert DragonErrors.NoJackpotToPay();

    // Calculate payouts: 69% to winner, 31% stays for next round
    uint256 winnerAmount = (totalJackpot * WINNER_PERCENTAGE) / BASIS_POINTS;
    uint256 rolloverAmount = totalJackpot - winnerAmount; // Remainder stays

    // Update state - only reduce by winner amount, rollover stays
    jackpotBalances[token] = rolloverAmount;
    lastWinTimestamp = block.timestamp;

    // Pay winner their 69%
    IERC20(token).safeTransfer(winner, winnerAmount);
    emit JackpotPaid(token, winner, winnerAmount, rolloverAmount);
  }

  /**
   * @dev Legacy function for interface compatibility - now pays 69% of jackpot
   * @param winner Winner address who gets 69% of the jackpot
   * @dev Amount parameter is ignored - winner always gets 69% of total jackpot
   */
  function payJackpot(address winner, uint256 /* amount */) external override onlyOwner nonReentrant {
    // Ignore the amount parameter - use our 69/31 split logic!
    if (wrappedNativeToken == address(0)) revert DragonErrors.WrappedTokenNotSet();
    if (winner == address(0)) revert DragonErrors.ZeroAddress();
    
    uint256 totalJackpot = jackpotBalances[wrappedNativeToken];
    if (totalJackpot == 0) revert DragonErrors.NoJackpotToPay();

    // Calculate payouts: 69% to winner, 31% stays for next round
    uint256 winnerAmount = (totalJackpot * WINNER_PERCENTAGE) / BASIS_POINTS;
    uint256 rolloverAmount = totalJackpot - winnerAmount; // Remainder stays

    // Update state - only reduce by winner amount, rollover stays
    jackpotBalances[wrappedNativeToken] = rolloverAmount;
    lastWinTimestamp = block.timestamp;

    // Pay winner their 69%
    IERC20(wrappedNativeToken).safeTransfer(winner, winnerAmount);
    emit JackpotPaid(wrappedNativeToken, winner, winnerAmount, rolloverAmount);
  }

  /**
   * @dev Get the time of the last jackpot win
   * @return timestamp The last win timestamp
   */
  function getLastWinTime() external view override returns (uint256 timestamp) {
    return lastWinTimestamp;
  }

  /**
   * @dev Set the wrapped native token address
   * @param _wrappedNativeToken The new wrapped native token address
   */
  function setWrappedNativeToken(address _wrappedNativeToken) external override onlyOwner {
    if (_wrappedNativeToken == address(0)) revert DragonErrors.ZeroAddress();
    address oldToken = wrappedNativeToken;
    wrappedNativeToken = _wrappedNativeToken;
    emit WrappedNativeTokenSet(oldToken, _wrappedNativeToken);
  }

  /**
   * @dev Emergency withdraw for non-core tokens only. Core token is `wrappedNativeToken`.
   *      Native balance is auto-wrapped in receive(); withdrawing native would drain core funds, so disallowed.
   */
  function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
    if (amount == 0) revert DragonErrors.ZeroAmount();

    // Disallow withdrawing core jackpot asset
    if (token == wrappedNativeToken) revert DragonErrors.UnauthorizedCaller();

    if (token == address(0)) {
      // Native should not be held materially (receive() auto-wraps). Block native withdraw to avoid optics issues.
      revert DragonErrors.UnauthorizedCaller();
    } else {
      // Withdraw only non-core ERC20s mistakenly sent to contract
      IERC20(token).safeTransfer(owner(), amount);
    }

    emit EmergencyWithdraw(token, owner(), amount);
  }

  /**
   * @dev Get jackpot balance for a specific token
   * @param token Token address
   * @return Jackpot balance
   */
  function getJackpotBalance(address token) external view returns (uint256) {
    return jackpotBalances[token];
  }

  /**
   * @dev Receive native tokens from FeeM and other sources - auto-wrap to wrapped native token
   * @dev Critical for DragonFeeMHelper integration on Sonic (wS)
   */
  receive() external payable nonReentrant {
    if (wrappedNativeToken == address(0)) revert DragonErrors.WrappedTokenNotSet();
    if (msg.value == 0) revert DragonErrors.ZeroAmount();

    // Auto-wrap received native token into wrapped native token for uniform accounting
    IWrappedNativeToken(wrappedNativeToken).deposit{value: msg.value}();

    // Track wrapped tokens in jackpot balance
    jackpotBalances[wrappedNativeToken] += msg.value;
    emit JackpotAdded(wrappedNativeToken, msg.value);
  }

  /**
   * @dev Enter the jackpot with Dragon tokens (placeholder for interface compatibility)
   * @param user Address of the user entering the jackpot (for events)
   * @param amount Amount of Dragon tokens (for events)
   */
  function enterJackpotWithDragon(address user, uint256 amount) external override {
    if (user == address(0)) revert DragonErrors.ZeroAddress();
    if (amount == 0) revert DragonErrors.ZeroAmount();
    // Placeholder - actual Dragon token handling done through fee distribution
    emit JackpotAdded(address(0), amount); // address(0) represents Dragon tokens
  }

  /**
   * @dev Enter the jackpot with wrapped native tokens
   * @param user Address of the user entering the jackpot
   * @param amount Amount of wrapped native tokens to enter
   */
  function enterJackpotWithWrappedNativeToken(address user, uint256 amount) external override {
    if (user == address(0)) revert DragonErrors.ZeroAddress();
    if (amount == 0) revert DragonErrors.ZeroAmount();
    if (wrappedNativeToken == address(0)) revert DragonErrors.WrappedTokenNotSet();

    // Transfer wrapped native tokens from caller
    IERC20(wrappedNativeToken).safeTransferFrom(msg.sender, address(this), amount);
    jackpotBalances[wrappedNativeToken] += amount;
    emit JackpotAdded(wrappedNativeToken, amount);
  }

  /**
   * @dev Enter the jackpot with native tokens (alternative to receive())
   * @param user Address of the user entering the jackpot
   */
  function enterJackpotWithNative(address user) external payable override {
    if (user == address(0)) revert DragonErrors.ZeroAddress();
    if (msg.value == 0) revert DragonErrors.ZeroAmount();
    if (wrappedNativeToken == address(0)) revert DragonErrors.WrappedTokenNotSet();

    // Auto-wrap the received ETH/SONIC into wrapped native token
    IWrappedNativeToken(wrappedNativeToken).deposit{value: msg.value}();
    jackpotBalances[wrappedNativeToken] += msg.value;
    emit JackpotAdded(wrappedNativeToken, msg.value);
  }

  // ========== VIEW FUNCTIONS ==========

  /**
   * @dev Get total jackpot value in wrapped native token
   */
  function getTotalJackpotValue() external view returns (uint256) {
    return jackpotBalances[wrappedNativeToken];
  }

  /**
   * @dev Calculate what winner would receive (69% of current jackpot)
   */
  function getWinnerPayout() external view returns (uint256) {
    uint256 totalJackpot = jackpotBalances[wrappedNativeToken];
    return (totalJackpot * WINNER_PERCENTAGE) / BASIS_POINTS;
  }

  /**
   * @dev Calculate what would rollover after a win (31% of current jackpot)
   */
  function getRolloverAmount() external view returns (uint256) {
    uint256 totalJackpot = jackpotBalances[wrappedNativeToken];
    return (totalJackpot * ROLLOVER_PERCENTAGE) / BASIS_POINTS;
  }

  // FeeM revenue routing handled by DragonFeeMHelper → receive() function

  // ========== SONIC FEEM INTEGRATION ==========

  /**
   * @dev Register my contract on Sonic FeeM
   * @notice This registers the contract with Sonic's Fee Manager for network benefits
   */
  function registerMe() external onlyOwner {
    (bool _success,) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
        abi.encodeWithSignature("selfRegister(uint256)", 143)
    );
    require(_success, "FeeM registration failed");
  }
}


