// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockLotteryManager
 * @dev Mock contract for testing lottery integration
 */
contract MockLotteryManager {
    uint256 private nextEntryId = 1;
    
    mapping(uint256 => address) public entryTraders;
    mapping(uint256 => uint256) public entryAmounts;
    
    event LotteryProcessed(
        uint256 indexed entryId,
        address indexed trader,
        address tokenIn,
        uint256 amountIn,
        uint256 swapValueUSD
    );
    
    function processSwapLottery(
        address trader,
        address tokenIn,
        uint256 amountIn,
        uint256 swapValueUSD
    ) external returns (uint256 entryId) {
        entryId = nextEntryId++;
        
        entryTraders[entryId] = trader;
        entryAmounts[entryId] = amountIn;
        
        emit LotteryProcessed(entryId, trader, tokenIn, amountIn, swapValueUSD);
        
        return entryId;
    }
    
    function getEntry(uint256 entryId) external view returns (address trader, uint256 amount) {
        return (entryTraders[entryId], entryAmounts[entryId]);
    }
}