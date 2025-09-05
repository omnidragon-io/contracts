// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DragonJackpotVault
 * @author  0xakita.eth
 * @notice  Holds the jackpot across wS, pfwS-36 (ERC-4626 wS vault shares), and pDRAGON (ERC-4626 DRAGON pod shares).
 *          - Payouts are made in wS only.
 *          - pfwS-36 is redeemed to wS when needed.
 *          - pDRAGON is *not* redeemed during payouts (accounted only in USD view via oracle).
 *
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC4626Minimal {
  function asset() external view returns (address);
  function convertToAssets(uint256 shares) external view returns (uint256 assets);
  function convertToShares(uint256 assets) external view returns (uint256 shares);
  function previewWithdraw(uint256 assets) external view returns (uint256 shares);
  function previewRedeem(uint256 shares) external view returns (uint256 assets);
  function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

interface IPriceOracleLike {
  /// @dev Returns TOKEN/USD price scaled to 1e18; timestamp is for staleness checks on the oracle side.
  function getLatestPrice() external view returns (int256 price1e18, uint256 timestamp);
}

contract DragonJackpotVault is Ownable, ReentrancyGuard, Pausable {
  using SafeERC20 for IERC20;

  // ---- Core tokens (set once, can be updated by owner if necessary) ----
  address public WRAPPED_SONIC;       // wS payout token
  address public PFWS36_SHARE_TOKEN;  // pfwS-36 vault share token (ERC-4626, underlying = wS)
  address public PDRAGON;             // pDRAGON vault share token (ERC-4626, underlying = DRAGON)
  address public DRAGON;              // DRAGON token (underlying for pDRAGON)

  // ---- Price oracles: TOKEN -> USD(1e18) ----
  mapping(address => address) public tokenUsdOracle; // token => oracle

  // ---- Authorized payout callers (e.g., OmniDragonLotteryManager) ----
  mapping(address => bool) public authorizedPayer;

  // ---- Events ----
  event PayerAuthorizationUpdated(address indexed caller, bool authorized);
  event TokenAddressesUpdated(address wS, address pfwS36, address pDRAGON, address dragon);
  event TokenUsdOracleSet(address indexed token, address indexed oracle);
  event JackpotPaid(address indexed winner, uint256 amountWS);
  event Pfws36Redeemed(uint256 shares, uint256 assetsReceived);
  event EmergencyTokenRecovered(address indexed token, address indexed to, uint256 amount);
  event EmergencyNativeRecovered(address indexed to, uint256 amount);

  // ---- Modifiers ----
  modifier onlyAuthorizedPayer() {
    require(authorizedPayer[msg.sender], "Not authorized to pay");
    _;
  }

  constructor(
    address _wS,
    address _pfwS36,
    address _pDRAGON,
    address _dragon,
    address _owner
  ) Ownable(_owner) {
    require(_wS != address(0) && _pfwS36 != address(0) && _pDRAGON != address(0) && _dragon != address(0), "zero addr");
    WRAPPED_SONIC = _wS;
    PFWS36_SHARE_TOKEN = _pfwS36;
    PDRAGON = _pDRAGON;
    DRAGON = _dragon;
    emit TokenAddressesUpdated(_wS, _pfwS36, _pDRAGON, _dragon);
  }

  // ---------------------------------------------------------------------
  // Admin
  // ---------------------------------------------------------------------

  function setTokens(
    address _wS,
    address _pfwS36,
    address _pDRAGON,
    address _dragon
  ) external onlyOwner {
    require(_wS != address(0) && _pfwS36 != address(0) && _pDRAGON != address(0) && _dragon != address(0), "zero addr");
    WRAPPED_SONIC = _wS;
    PFWS36_SHARE_TOKEN = _pfwS36;
    PDRAGON = _pDRAGON;
    DRAGON = _dragon;
    emit TokenAddressesUpdated(_wS, _pfwS36, _pDRAGON, _dragon);
  }

  /// @notice Set or update the TOKEN/USD(1e18) oracle used for USD views.
  function setTokenUsdOracle(address token, address oracle) external onlyOwner {
    require(token != address(0) && oracle != address(0), "zero addr");
    tokenUsdOracle[token] = oracle;
    emit TokenUsdOracleSet(token, oracle);
  }

  function authorizePayer(address caller, bool auth) external onlyOwner {
    authorizedPayer[caller] = auth;
    emit PayerAuthorizationUpdated(caller, auth);
  }

  function pause() external onlyOwner { _pause(); }
  function unpause() external onlyOwner { _unpause(); }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  function _sharesToUnderlying(address vault, uint256 shares) internal view returns (address underlying, uint256 assets) {
    if (shares == 0 || vault == address(0)) return (address(0), 0);
    try IERC4626Minimal(vault).asset() returns (address u) {
      underlying = u;
      try IERC4626Minimal(vault).convertToAssets(shares) returns (uint256 a) {
        assets = a;
      } catch {
        assets = 0;
            }
        } catch {
      underlying = address(0);
      assets = 0;
    }
  }

  function _toUsd1e6(address token, uint256 amount) internal view returns (uint256) {
    if (amount == 0) return 0;
    address oracle = tokenUsdOracle[token];
    if (oracle == address(0)) return 0;
    try IPriceOracleLike(oracle).getLatestPrice() returns (int256 px1e18, uint256 /*ts*/) {
      if (px1e18 <= 0) return 0;
      uint8 dec;
      try IERC20Metadata(token).decimals() returns (uint8 d) { dec = d; } catch { dec = 18; }
      // USD(1e6) = amount * price(1e18) / 10^dec / 1e12
      return (amount * uint256(px1e18)) / (10 ** dec) / 1e12;
    } catch {
      return 0;
    }
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  // ---------------------------------------------------------------------
  // Public views
  // ---------------------------------------------------------------------

  /**
   * @notice Raw token balances held by the vault (no conversions)
   */
  function getJackpotTokenBalances()
    external
    view
    returns (
      uint256 wsBalance,
      uint256 pfws36Shares,
      uint256 pdragonShares,
      uint256 dragonBalance
    )
  {
    wsBalance      = IERC20(WRAPPED_SONIC).balanceOf(address(this));
    pfws36Shares   = IERC20(PFWS36_SHARE_TOKEN).balanceOf(address(this));
    pdragonShares  = IERC20(PDRAGON).balanceOf(address(this));
    dragonBalance  = IERC20(DRAGON).balanceOf(address(this)); // usually zero unless someone sent DRAGON directly
  }

  /**
   * @notice How much **wS can be paid out right now**, without touching pDRAGON.
   * @dev This is what the lottery should use to size prizes.
   */
  function getJackpotCapacityWS() public view returns (uint256 wsCapacity) {
    uint256 wsBal = IERC20(WRAPPED_SONIC).balanceOf(address(this));
    uint256 pfws36Bal = IERC20(PFWS36_SHARE_TOKEN).balanceOf(address(this));
    (, uint256 wsFromPfws36) = _sharesToUnderlying(PFWS36_SHARE_TOKEN, pfws36Bal);
    wsCapacity = wsBal + wsFromPfws36;
  }

  /**
   * @notice Backwards-compatible jackpot getter used by OmniDragonLotteryManager.
   * @dev Returns **wS payout capacity** (wS + pfwS-36 converted to wS). Does NOT include pDRAGON,
   *      because pDRAGON is not wS and cannot be paid without separate unwind logic.
   */
  function getJackpotBalance() public view returns (uint256) {
    return getJackpotCapacityWS();
  }

  /**
   * @notice USD(1e6) valuation of everything: wS + pfwS-36 (as wS) + pDRAGON (as DRAGON) + raw DRAGON.
   * @dev For UI/display. Oracles must be configured via setTokenUsdOracle.
   */
  function getJackpotUsd1e6() public view returns (uint256 totalUsd) {
    // wS (raw)
    uint256 wsBal = IERC20(WRAPPED_SONIC).balanceOf(address(this));
    uint256 wsUsd = _toUsd1e6(WRAPPED_SONIC, wsBal);

    // pfwS-36 -> wS
    uint256 pfws36Shares = IERC20(PFWS36_SHARE_TOKEN).balanceOf(address(this));
    (, uint256 wsFromPfws36) = _sharesToUnderlying(PFWS36_SHARE_TOKEN, pfws36Shares);
    uint256 pfws36Usd = _toUsd1e6(WRAPPED_SONIC, wsFromPfws36);

    // pDRAGON -> DRAGON
    uint256 pdragonShares = IERC20(PDRAGON).balanceOf(address(this));
    (, uint256 dragonFromPdragon) = _sharesToUnderlying(PDRAGON, pdragonShares);
    uint256 pdragonUsd = _toUsd1e6(DRAGON, dragonFromPdragon);

    // raw DRAGON (if any)
    uint256 dragonBal = IERC20(DRAGON).balanceOf(address(this));
    uint256 dragonUsd = _toUsd1e6(DRAGON, dragonBal);

    totalUsd = wsUsd + pfws36Usd + pdragonUsd + dragonUsd;
  }

  /**
   * @notice Detailed USD(1e6) breakdown for front-ends and monitoring.
   */
  function getJackpotBreakdownUsd1e6()
    external
    view
    returns (
      // underlying amounts
      uint256 wsRaw, uint256 wsFromPfws36, uint256 dragonFromPdragon, uint256 dragonRaw,
      // USD valuations
      uint256 wsUsd, uint256 pfws36Usd, uint256 pdragonUsd, uint256 dragonUsd,
      uint256 totalUsd
    )
  {
    wsRaw = IERC20(WRAPPED_SONIC).balanceOf(address(this));

    uint256 pfws36Shares = IERC20(PFWS36_SHARE_TOKEN).balanceOf(address(this));
    (, wsFromPfws36) = _sharesToUnderlying(PFWS36_SHARE_TOKEN, pfws36Shares);

    uint256 pdragonShares = IERC20(PDRAGON).balanceOf(address(this));
    (, dragonFromPdragon) = _sharesToUnderlying(PDRAGON, pdragonShares);

    dragonRaw = IERC20(DRAGON).balanceOf(address(this));

    wsUsd       = _toUsd1e6(WRAPPED_SONIC, wsRaw);
    pfws36Usd   = _toUsd1e6(WRAPPED_SONIC, wsFromPfws36);
    pdragonUsd  = _toUsd1e6(DRAGON, dragonFromPdragon);
    dragonUsd   = _toUsd1e6(DRAGON, dragonRaw);

    totalUsd = wsUsd + pfws36Usd + pdragonUsd + dragonUsd;
  }

  // ---------------------------------------------------------------------
  // Payouts (wS only)
  // ---------------------------------------------------------------------

  /**
   * @notice Pay a jackpot in **wS units**. Pulls wS first, then redeems pfwS-36 for the shortfall.
   * @dev Callable only by authorized lottery manager(s). No DRAGON/pDRAGON is touched here.
   */
  function payJackpot(address recipient, uint256 amountWS)
    external
    nonReentrant
    whenNotPaused
    onlyAuthorizedPayer
  {
    require(recipient != address(0), "zero recipient");
    require(amountWS > 0, "zero amount");

    uint256 wsBal = IERC20(WRAPPED_SONIC).balanceOf(address(this));
    uint256 toSend = _min(amountWS, wsBal);
    if (toSend > 0) {
      IERC20(WRAPPED_SONIC).safeTransfer(recipient, toSend);
    }

    uint256 remaining = amountWS - toSend;
    if (remaining > 0) {
      uint256 pfws36Shares = IERC20(PFWS36_SHARE_TOKEN).balanceOf(address(this));
      require(pfws36Shares > 0, "insufficient wS + pfwS36");

      // Ask vault how many shares are needed for the requested assets
      uint256 sharesNeeded;
      // Prefer previewWithdraw(assets) if implemented
      try IERC4626Minimal(PFWS36_SHARE_TOKEN).previewWithdraw(remaining) returns (uint256 s) {
        sharesNeeded = s;
      } catch {
        // Fallback: approximate using convertToShares
        try IERC4626Minimal(PFWS36_SHARE_TOKEN).convertToShares(remaining) returns (uint256 s2) {
          sharesNeeded = s2;
        } catch {
          // Final fallback: redeem everything and send whatever we get (bounded by remaining)
          sharesNeeded = pfws36Shares;
        }
      }

      if (sharesNeeded > pfws36Shares) {
        sharesNeeded = pfws36Shares; // redeem as much as we can
      }

      uint256 assetsBefore = IERC20(WRAPPED_SONIC).balanceOf(address(this));
      uint256 assetsOut = 0;
      try IERC4626Minimal(PFWS36_SHARE_TOKEN).redeem(sharesNeeded, address(this), address(this)) returns (uint256 a) {
        assetsOut = a;
      } catch {
        revert("pfwS36 redeem failed");
      }
      emit Pfws36Redeemed(sharesNeeded, assetsOut);

      // Transfer the remainder (up to what we actually redeemed)
      uint256 newWsBal = IERC20(WRAPPED_SONIC).balanceOf(address(this));
      uint256 delta = newWsBal - assetsBefore;
      uint256 toSend2 = _min(remaining, delta);
      require(toSend2 > 0, "no wS redeemed");

      IERC20(WRAPPED_SONIC).safeTransfer(recipient, toSend2);

      // If still short, revert to avoid partial payouts beyond the model
      require(toSend + toSend2 == amountWS, "insufficient liquidity");
    }

    emit JackpotPaid(recipient, amountWS);
  }

  // ---------------------------------------------------------------------
  // Emergency / Recovery
  // ---------------------------------------------------------------------

  /// @notice Recover arbitrary ERC20 tokens (e.g. mistaken sends). Not for jackpot flow.
  function recoverToken(address token, address to, uint256 amount) external onlyOwner nonReentrant {
    require(to != address(0), "zero to");
    IERC20(token).safeTransfer(to, amount);
    emit EmergencyTokenRecovered(token, to, amount);
  }

  /// @notice Recover native currency if any.
  function recoverNative(address payable to, uint256 amount) external onlyOwner nonReentrant {
    require(to != address(0), "zero to");
    (bool ok, ) = to.call{value: amount}("");
    require(ok, "native transfer failed");
    emit EmergencyNativeRecovered(to, amount);
  }

  receive() external payable {}
  fallback() external payable {}
}
