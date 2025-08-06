// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title OmniDragonFeeLib
 * @author 0xakita.eth
 * @dev Library for fee calculation and distribution logic
 * @notice Extracted from omniDRAGON to reduce contract size and improve modularity
 *
 * This library handles:
 * - Fee calculation with different rates for buy/sell
 * - Fee distribution to jackpot, veDRAGON, and burn
 * - Native token conversion and routing
 * - Emergency recovery mechanisms
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
library OmniDragonFeeLib {
  using SafeERC20 for IERC20;

  // ========== EVENTS ==========
  event FeesDistributed(
    address indexed token,
    uint256 jackpotAmount,
    uint256 veDragonAmount,
    uint256 burnAmount,
    uint256 totalFees
  );
  
  event NativeConversion(
    address indexed dexPair,
    uint256 tokenAmount,
    uint256 nativeReceived
  );

  // ========== STRUCTS ==========
  
  struct Fees {
    uint256 jackpot;
    uint256 veDRAGON;
    uint256 burn;
    uint256 total;
  }

  struct FeeAmounts {
    uint256 jackpotFee;
    uint256 veDragonFee;
    uint256 burnFee;
    uint256 totalFeeAmount;
  }

  struct FeeDistributionParams {
    address token;
    address jackpotVault;
    address veDragonContract;
    address burnAddress;
    uint256 amount;
  }

  // ========== CORE FUNCTIONS ==========

  /**
   * @dev Calculate fee breakdown from total fee amount
   * @param amount Total amount being transferred
   * @param feeRates Fee rates structure
   * @return feeAmounts Calculated fee amounts
   */
  function calculateFeeBreakdown(
    uint256 amount,
    Fees memory feeRates
  ) internal pure returns (FeeAmounts memory feeAmounts) {
    feeAmounts.totalFeeAmount = (amount * feeRates.total) / 10000;
    
    if (feeAmounts.totalFeeAmount > 0) {
      feeAmounts.jackpotFee = (feeAmounts.totalFeeAmount * feeRates.jackpot) / feeRates.total;
      feeAmounts.veDragonFee = (feeAmounts.totalFeeAmount * feeRates.veDRAGON) / feeRates.total;
      feeAmounts.burnFee = (feeAmounts.totalFeeAmount * feeRates.burn) / feeRates.total;
    }
  }

  /**
   * @dev Execute fee distribution to all destinations
   * @param params Distribution parameters
   */
  function executeFeeDistribution(FeeDistributionParams memory params) internal {
    require(params.amount > 0, "OmniDragonFeeLib: Zero amount");
    require(params.token != address(0), "OmniDragonFeeLib: Zero token address");

    // Calculate individual amounts (simple equal distribution for now)
    uint256 thirdAmount = params.amount / 3;
    uint256 remainder = params.amount - (thirdAmount * 3);

    // Distribute to jackpot vault
    if (params.jackpotVault != address(0) && thirdAmount > 0) {
      IERC20(params.token).safeTransfer(params.jackpotVault, thirdAmount);
    }

    // Distribute to veDRAGON contract
    if (params.veDragonContract != address(0) && thirdAmount > 0) {
      IERC20(params.token).safeTransfer(params.veDragonContract, thirdAmount);
    }

    // Burn tokens (send to burn address)
    if (params.burnAddress != address(0) && (thirdAmount + remainder) > 0) {
      IERC20(params.token).safeTransfer(params.burnAddress, thirdAmount + remainder);
    }

    emit FeesDistributed(
      params.token,
      thirdAmount,
      thirdAmount,
      thirdAmount + remainder,
      params.amount
    );
  }

  /**
   * @dev Convert tokens to native currency via DEX pair
   * @param token Token to convert
   * @param amount Amount to convert
   * @param dexPair DEX pair address for conversion
   * @param recipient Recipient of native tokens
   * @return nativeReceived Amount of native tokens received
   */
  function convertToNative(
    address token,
    uint256 amount,
    address dexPair,
    address recipient
  ) internal returns (uint256 nativeReceived) {
    require(token != address(0), "OmniDragonFeeLib: Zero token address");
    require(dexPair != address(0), "OmniDragonFeeLib: Zero DEX pair address");
    require(amount > 0, "OmniDragonFeeLib: Zero amount");

    uint256 initialBalance = recipient.balance;

    // Transfer tokens to DEX pair and execute swap
    IERC20(token).safeTransfer(dexPair, amount);
    
    // Simple swap logic (would need to be customized for specific DEX)
    (bool success, ) = dexPair.call(
      abi.encodeWithSignature("swap(uint256,uint256,address,bytes)", 0, amount, recipient, "")
    );
    
    require(success, "OmniDragonFeeLib: Swap failed");

    nativeReceived = recipient.balance - initialBalance;
    
    emit NativeConversion(dexPair, amount, nativeReceived);
  }

  /**
   * @dev Calculate optimal fee split between different mechanisms
   * @param totalAmount Total amount to process
   * @param isBuy Whether this is a buy transaction
   * @return jackpotShare Share for jackpot
   * @return veDragonShare Share for veDRAGON
   * @return burnShare Share for burn
   */
  function calculateOptimalSplit(
    uint256 totalAmount,
    bool isBuy
  ) internal pure returns (uint256 jackpotShare, uint256 veDragonShare, uint256 burnShare) {
    // Different allocation strategies for buy vs sell
    if (isBuy) {
      // Buy: More to jackpot and veDRAGON for user incentives
      jackpotShare = (totalAmount * 4000) / 10000; // 40%
      veDragonShare = (totalAmount * 4000) / 10000; // 40%
      burnShare = (totalAmount * 2000) / 10000; // 20%
    } else {
      // Sell: More to burn for deflationary pressure
      jackpotShare = (totalAmount * 3000) / 10000; // 30%
      veDragonShare = (totalAmount * 3000) / 10000; // 30%
      burnShare = (totalAmount * 4000) / 10000; // 40%
    }
  }

  /**
   * @dev Emergency function to rescue tokens
   * @param token Token to rescue
   * @param amount Amount to rescue
   * @param to Recipient address
   */
  function emergencyRescue(
    address token,
    uint256 amount,
    address to
  ) internal {
    require(to != address(0), "OmniDragonFeeLib: Zero recipient address");
    require(amount > 0, "OmniDragonFeeLib: Zero amount");

    if (token == address(0)) {
      // Rescue native tokens
      (bool success, ) = payable(to).call{value: amount}("");
      require(success, "OmniDragonFeeLib: Native transfer failed");
    } else {
      // Rescue ERC20 tokens
      IERC20(token).safeTransfer(to, amount);
    }
  }

  /**
   * @dev Validate fee rates don't exceed maximum limits
   * @param feeRates Fee rates to validate
   * @param maxTotalFee Maximum allowed total fee (in basis points)
   */
  function validateFeeRates(Fees memory feeRates, uint256 maxTotalFee) internal pure {
    require(feeRates.total <= maxTotalFee, "OmniDragonFeeLib: Total fee too high");
    require(
      feeRates.jackpot + feeRates.veDRAGON + feeRates.burn == feeRates.total,
      "OmniDragonFeeLib: Fee breakdown mismatch"
    );
  }
} 