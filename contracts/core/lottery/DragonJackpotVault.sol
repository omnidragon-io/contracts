// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DragonJackpotVault
 * @author  0xakita.eth (reworked with safety-first accounting)
 *
 * Key points:
 * - pfwS-36 is an ERC-4626 autocompounding vault for wS → use convertToAssets()/withdraw()/redeem()
 * - pDRAGON is an ERC-4626 vault for DRAGON (Peapods) → convertToAssets()/redeem() to DRAGON
 * - Winners are ALWAYS paid in wS
 * - pDRAGON → DRAGON → wS unwinding is delegated to a whitelisted `unwinder`
 * - USD valuation uses pluggable token->oracle (price in 1e18; USD result in 1e6)
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC4626 {
  function asset() external view returns (address);
  function convertToAssets(uint256 shares) external view returns (uint256 assets);
  function convertToShares(uint256 assets) external view returns (uint256 shares);
  function previewWithdraw(uint256 assets) external view returns (uint256 shares);
  function previewRedeem(uint256 shares) external view returns (uint256 assets);
  function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
  function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

interface IPriceOracleLike {
  /// @dev returns TOKEN/USD price with 1e18 decimals, timestamp (not enforced here)
  function getLatestPrice() external view returns (int256 price1e18, uint256 timestamp);
}

contract DragonJackpotVault is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // ---- Core assets
  IERC20 public immutable wS;                // Wrapped Sonic (native)
  IERC4626 public immutable pfwS36;                    // Autocompounding vault for wS (shares)
  IERC4626 public immutable pDRAGON;                   // Peapods vault for DRAGON (shares)

  IERC20 public immutable DRAGON;            // Underlying token of pDRAGON

  // ---- Roles / integrations
  address public unwinder;                   // Keeper/unwinder allowed to redeem pDRAGON and pull DRAGON out
  mapping(address => bool) public authorizedPayers;  // Authorized contracts that can call payJackpot

  // ---- Oracles (TOKEN -> Oracle returning TOKEN/USD with 1e18)
  mapping(address => IPriceOracleLike) public tokenUsdOracle;

  // ---- Events
  event JackpotPaid(address indexed winner, uint256 amountWS);
  event PfwSRedeemed(uint256 shares, uint256 assetsWS);
  event PDragonRedeemed(uint256 shares, uint256 assetsDRAGON);
  event UnwinderSet(address indexed unwinder);
  event TokenOracleSet(address indexed token, address indexed oracle);
  event DragonPulledToUnwinder(uint256 amount);
  event PDragonRedeemedToVault(uint256 shares, uint256 assetsDRAGON);
  event PayerAuthorizationUpdated(address indexed payer, bool authorized);

  // ---- Errors
  error InvalidAddress();
  error InsufficientLiquidity();
  error NotUnwinder();
  error NotAuthorizedPayer();
  error OracleUnavailable(address token);

  constructor(
    address _wS,
    address _pfwS36,
    address _pDRAGON
  ) Ownable(msg.sender) {
    if (_wS == address(0) || _pfwS36 == address(0) || _pDRAGON == address(0)) revert InvalidAddress();

    // Wire tokens
    wS = IERC20(_wS);
    pfwS36 = IERC4626(_pfwS36);
    pDRAGON = IERC4626(_pDRAGON);

    // Sanity for underlying tokens
    address pfwSAsset = pfwS36.asset();    // should be wS
    require(pfwSAsset == _wS, "pfwS-36 asset != wS");

    // Try to get DRAGON address, but handle beacon proxy pattern gracefully
    address drg;
    try pDRAGON.asset() returns (address _drg) {
      drg = _drg;
    } catch {
      // If asset() fails (beacon proxy not initialized), use hardcoded DRAGON address
      // DRAGON token on Sonic: 0x40f531123bce8962D9ceA52a3B150023bef488Ed (ffDRAGON)
      drg = 0x40f531123bce8962D9ceA52a3B150023bef488Ed;
    }
    DRAGON = IERC20(drg);
  }

  // -----------------------------
  // Admin & configuration
  // -----------------------------

  function setUnwinder(address _unwinder) external onlyOwner {
    if (_unwinder == address(0)) revert InvalidAddress();
    unwinder = _unwinder;
    emit UnwinderSet(_unwinder);
  }

  /// @notice Authorize or revoke a payer (e.g., lottery manager)
  function setAuthorizedPayer(address payer, bool authorized) external onlyOwner {
    if (payer == address(0)) revert InvalidAddress();
    authorizedPayers[payer] = authorized;
    emit PayerAuthorizationUpdated(payer, authorized);
  }

  /// @notice Set or update a TOKEN->USD oracle (1e18 price)
  function setTokenUsdOracle(address token, address oracle) external onlyOwner {
    if (token == address(0) || oracle == address(0)) revert InvalidAddress();
    tokenUsdOracle[token] = IPriceOracleLike(oracle);
    emit TokenOracleSet(token, oracle);
  }

  // -----------------------------
  // Views: balances & valuation
  // -----------------------------

  /// @notice Raw balances held by the vault
  /// @return wsDirect   wS directly held
  /// @return pfwShares  pfwS-36 share balance
  /// @return drgDirect  DRAGON directly held (if any)
  /// @return pdrgShares pDRAGON share balance
  function getRawBalances()
    public
    view
    returns (uint256 wsDirect, uint256 pfwShares, uint256 drgDirect, uint256 pdrgShares)
  {
    wsDirect   = wS.balanceOf(address(this));
    pfwShares  = IERC20(address(pfwS36)).balanceOf(address(this));
    drgDirect  = DRAGON.balanceOf(address(this));
    pdrgShares = IERC20(address(pDRAGON)).balanceOf(address(this));
  }

  /// @notice Underlying exposures (after ERC-4626 conversions)
  /// @dev pfwS-36 -> wS / pDRAGON -> DRAGON
  /// @return totalWS     wS exposure = direct wS + pfwS-36 converted to assets
  /// @return totalDRAGON DRAGON exposure = direct DRAGON + pDRAGON converted to assets
  function getUnderlyingExposures()
    public
    view
    returns (uint256 totalWS, uint256 totalDRAGON)
  {
    (uint256 wsDirect, uint256 pfwShares, uint256 drgDirect, uint256 pdrgShares) = getRawBalances();

    uint256 wsFromPfw = pfwShares == 0 ? 0 : pfwS36.convertToAssets(pfwShares);
    uint256 drgFromP = pdrgShares == 0 ? 0 : pDRAGON.convertToAssets(pdrgShares);

    totalWS = wsDirect + wsFromPfw;
    totalDRAGON = drgDirect + drgFromP;
  }

  /// @notice Convenience (legacy) "jackpot balance" measured in wS units you can *reasonably* expect to realize quickly
  /// @dev This is an estimate: direct wS + pfwS-36.convertToAssets(shares). DRAGON exposure is intentionally excluded.
  function getJackpotBalance() external view returns (uint256) {
    (uint256 wsDirect, uint256 pfwShares,,) = getRawBalances();
    uint256 wsFromPfw = pfwShares == 0 ? 0 : pfwS36.convertToAssets(pfwShares);
    return wsDirect + wsFromPfw;
  }

  /// @notice Full USD valuation (1e6), using configured TOKEN→USD (1e18) oracles
  /// @dev Returns (wsUsd, dragonUsd, totalUsd). If an oracle is missing, that leg returns 0.
  function getJackpotUsd()
    external
    view
    returns (uint256 wsUsd1e6, uint256 dragonUsd1e6, uint256 totalUsd1e6)
  {
    (uint256 totalWS, uint256 totalDRAGON) = getUnderlyingExposures();
    wsUsd1e6     = _toUsd1e6(address(wS), totalWS);
    dragonUsd1e6 = _toUsd1e6(address(DRAGON), totalDRAGON);
    totalUsd1e6  = wsUsd1e6 + dragonUsd1e6;
  }

  // -----------------------------
  // Payout & liquidity management
  // -----------------------------

  /**
   * @notice Pay jackpot strictly in wS
   * @dev Will redeem pfwS-36 shares if needed. Will NOT auto-swap DRAGON; if not enough wS + pfwS-36, it reverts.
   */
  function payJackpot(address to, uint256 amountWS) external nonReentrant {
    if (msg.sender != owner() && !authorizedPayers[msg.sender]) revert NotAuthorizedPayer();
    require(to != address(0), "invalid winner");
    if (amountWS == 0) return;

    // 1) Use direct wS
    uint256 wsBal = wS.balanceOf(address(this));
    if (wsBal >= amountWS) {
      wS.safeTransfer(to, amountWS);
      emit JackpotPaid(to, amountWS);
      return;
    }

    // 2) Redeem pfwS-36 shares to cover the shortfall
    uint256 shortfall = amountWS - wsBal;
    uint256 pfwShares = IERC20(address(pfwS36)).balanceOf(address(this));
    if (pfwShares > 0) {
      uint256 sharesNeeded;
      // Prefer previewWithdraw if implemented
      try pfwS36.previewWithdraw(shortfall) returns (uint256 s) {
        sharesNeeded = s;
      } catch {
        // fallback: convertToShares (may differ slightly due to fees/rounding)
        sharesNeeded = pfwS36.convertToShares(shortfall);
      }

      if (sharesNeeded > pfwShares) {
        sharesNeeded = pfwShares;
      }

      if (sharesNeeded > 0) {
        // redeem()/withdraw() delivers underlying to receiver
        // We'll use redeem to pull the maximum wS from sharesNeeded
        uint256 assetsOut = pfwS36.redeem(sharesNeeded, address(this), address(this));
        emit PfwSRedeemed(sharesNeeded, assetsOut);
      }
    }

    // 3) Transfer if sufficient now
    wsBal = wS.balanceOf(address(this));
    if (wsBal < amountWS) {
      revert InsufficientLiquidity();
    }

    wS.safeTransfer(to, amountWS);
    emit JackpotPaid(to, amountWS);
  }

  /**
   * @notice (Keeper) Redeem pDRAGON shares to DRAGON and keep DRAGON inside this vault.
   * @dev Unwinder can then pull DRAGON out and swap off-vault to refill wS buffer.
   */
  function redeemPDragonToDragon(uint256 shares) external nonReentrant {
    if (msg.sender != owner() && msg.sender != unwinder) revert NotUnwinder();
    if (shares == 0) return;

    uint256 assets = pDRAGON.redeem(shares, address(this), address(this));
    emit PDragonRedeemedToVault(shares, assets);
  }

  /**
   * @notice (Keeper) Pull DRAGON out to the unwinder for off-vault swapping.
   */
  function pullDragonToUnwinder(uint256 amount) external nonReentrant {
    if (msg.sender != owner() && msg.sender != unwinder) revert NotUnwinder();
    if (amount == 0) return;

    DRAGON.safeTransfer(unwinder, amount);
    emit DragonPulledToUnwinder(amount);
  }

  // -----------------------------
  // Internal valuation helpers
  // -----------------------------

  function _toUsd1e6(address token, uint256 amount) internal view returns (uint256) {
    if (amount == 0) return 0;

    IPriceOracleLike oracle = tokenUsdOracle[token];
    if (address(oracle) == address(0)) {
      return 0; // no revert in views: return 0 for missing oracle leg
    }

    (int256 p1e18, /*ts*/) = oracle.getLatestPrice();
    if (p1e18 <= 0) return 0;

    uint8 dec;
    try IERC20Metadata(token).decimals() returns (uint8 d) { dec = d; } catch { dec = 18; }

    // USD(1e6) = amount * price(1e18) / (10^decimals * 1e12)
    return (amount * uint256(p1e18)) / (10 ** dec) / 1e12;
  }

  // -----------------------------
  // Rescue / admin
  // -----------------------------

  function rescueToken(IERC20 token, address to, uint256 amount) external onlyOwner {
    require(to != address(0), "invalid to");
    token.safeTransfer(to, amount);
  }

  receive() external payable {}
  fallback() external payable {}
}
