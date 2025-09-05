// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPeapods
 * @notice Interface for all Peapods protocol interactions
 * @dev Combines bonding and vault functionality
 */
interface IPeapods {
    // ============ Bonding Functions ============
    
    /**
     * @dev Bond tokens to get pDRAGON (index fund share)
     * @param _indexFund The index fund to receive (pDRAGON address)
     * @param _token Token to bond (FatFinger DRAGON)
     * @param _amount Amount to bond
     * @param _amountMintMin Minimum pDRAGON to receive
     * @return Amount of pDRAGON received
     */
    function bond(
        address _indexFund,
        address _token,
        uint256 _amount,
        uint256 _amountMintMin
    ) external returns (uint256);
    
    // ============ ERC-4626 Vault Functions ============
    
    /**
     * @dev Deposit assets to receive shares (for pfwS-36 vault)
     */
    function deposit(uint256 assets, address receiver) external payable returns (uint256 shares);
    
    /**
     * @dev Withdraw assets by burning shares
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    
    /**
     * @dev Redeem shares for assets
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    
    // ============ View Functions ============
    
    function balanceOf(address account) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function maxRedeem(address owner) external view returns (uint256);
    function getAllAssets() external view returns (address[] memory);
}
