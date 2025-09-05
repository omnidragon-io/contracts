// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PartnerBribeDistributor
 * @dev Lightweight bribe distributor that pays veDRAGON voters of a partner for a given period,
 *      proportional to votes recorded by veDRAGONBoostManager. No staking pools required.
 */

// Minimal interface to read voting data from veDRAGONBoostManager
interface IBoostVotes {
  function currentPeriod() external view returns (uint256);
  function votingPeriodLength() external view returns (uint64);
  function userVotes(uint256 period, address user, uint256 partnerId) external view returns (uint256);
  function partnerVotes(uint256 period, uint256 partnerId) external view returns (uint256);
}

contract PartnerBribeDistributor is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // Constants
  uint256 public constant FEE_PRECISION = 10000; // 10000 = 100%

  // Core refs
  address public immutable boostManager; // veDRAGONBoostManager
  address public treasury; // optional protocol fee receiver

  // Fees
  uint256 public protocolFeeBps; // e.g. 300 = 3%

  // period => partnerId => token => total bribe amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public periodPartnerTokenBribe;

  // period => partnerId => token => user => claimed amount
  mapping(uint256 => mapping(uint256 => mapping(address => mapping(address => uint256)))) public userClaimed;

  // Events
  event BribeDeposited(uint256 indexed period, uint256 indexed partnerId, address indexed token, uint256 amount, address from);
  event Claimed(uint256 indexed period, uint256 indexed partnerId, address indexed token, address user, uint256 amount);
  event ProtocolFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
  event TreasuryUpdated(address oldTreasury, address newTreasury);

  constructor(address _boostManager, address _treasury, uint256 _protocolFeeBps) Ownable(msg.sender) {
    require(_boostManager != address(0), "Zero boostManager");
    boostManager = _boostManager;
    treasury = _treasury; // can be zero initially
    require(_protocolFeeBps <= 3000, "Fee too high");
    protocolFeeBps = _protocolFeeBps;
  }

  // ============ Admin ============

  function setProtocolFeeBps(uint256 _bps) external onlyOwner {
    require(_bps <= 3000, "Fee too high");
    uint256 old = protocolFeeBps;
    protocolFeeBps = _bps;
    emit ProtocolFeeUpdated(old, _bps);
  }

  function setTreasury(address _treasury) external onlyOwner {
    address old = treasury;
    treasury = _treasury;
    emit TreasuryUpdated(old, _treasury);
  }

  // ============ Bribe Deposit ============

  /**
   * @notice Deposit bribe tokens for a partner and period.
   * @param partnerId Partner identifier (index from registry)
   * @param token ERC20 token address to bribe with
   * @param amount Amount to deposit
   * @param forNextPeriod If true, bribe is applied to next period; otherwise current period
   */
  function depositBribe(
    uint256 partnerId,
    address token,
    uint256 amount,
    bool forNextPeriod
  ) external nonReentrant {
    require(token != address(0), "Zero token");
    require(amount > 0, "Zero amount");

    // Determine target period
    uint256 period = IBoostVotes(boostManager).currentPeriod();
    if (forNextPeriod) period += 1;

    // Pull tokens in
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    // Take optional protocol fee
    uint256 fee = (amount * protocolFeeBps) / FEE_PRECISION;
    uint256 netAmount = amount - fee;
    if (fee > 0 && treasury != address(0)) {
      IERC20(token).safeTransfer(treasury, fee);
    }

    // Record net bribe for this period/partner/token
    periodPartnerTokenBribe[period][partnerId][token] += netAmount;

    emit BribeDeposited(period, partnerId, token, netAmount, msg.sender);
  }

  // ============ Claiming ============

  function getUserClaimable(
    uint256 period,
    uint256 partnerId,
    address token,
    address user
  ) public view returns (uint256) {
    // Ensure period has ended: block time >= (period + 1) * votingPeriodLength
    uint64 len = IBoostVotes(boostManager).votingPeriodLength();
    // If len == 0 (should not happen), treat as ended to avoid locking funds
    if (len > 0) {
      require(block.timestamp >= (period + 1) * uint256(len), "Period not ended");
    }

    uint256 totalBribe = periodPartnerTokenBribe[period][partnerId][token];
    if (totalBribe == 0) return 0;

    uint256 totalVotes = IBoostVotes(boostManager).partnerVotes(period, partnerId);
    if (totalVotes == 0) return 0;

    uint256 votes = IBoostVotes(boostManager).userVotes(period, user, partnerId);
    if (votes == 0) return 0;

    uint256 entitled = (totalBribe * votes) / totalVotes;
    uint256 already = userClaimed[period][partnerId][token][user];
    if (entitled <= already) return 0;
    return entitled - already;
  }

  function claim(
    uint256 period,
    uint256 partnerId,
    address token
  ) external nonReentrant {
    uint256 claimable = getUserClaimable(period, partnerId, token, msg.sender);
    require(claimable > 0, "Nothing to claim");

    userClaimed[period][partnerId][token][msg.sender] += claimable;
    IERC20(token).safeTransfer(msg.sender, claimable);

    emit Claimed(period, partnerId, token, msg.sender, claimable);
  }

  function claimMany(
    uint256[] calldata periods,
    uint256[] calldata partnerIds,
    address[] calldata tokens
  ) external nonReentrant {
    require(periods.length == partnerIds.length && periods.length == tokens.length, "Length mismatch");
    uint256 total;
    for (uint256 i = 0; i < periods.length; i++) {
      uint256 claimable = getUserClaimable(periods[i], partnerIds[i], tokens[i], msg.sender);
      if (claimable > 0) {
        userClaimed[periods[i]][partnerIds[i]][tokens[i]][msg.sender] += claimable;
        IERC20(tokens[i]).safeTransfer(msg.sender, claimable);
        total += claimable;
        emit Claimed(periods[i], partnerIds[i], tokens[i], msg.sender, claimable);
      }
    }
    // total is unused, but kept for potential future event/return
    total;
  }
}


