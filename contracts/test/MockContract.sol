// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockContract
 * @dev Generic mock contract for testing DEX integrations
 */
contract MockContract {
    
    mapping(address => uint256) public tokenBalances;
    
    event TokenReceived(address token, uint256 amount, address from);
    event MockFunctionCalled(address caller);
    
    // Basic mock function
    function mockFunction() external pure returns (bool) {
        return true;
    }
    
    // Mock swap function (for testing purposes)
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external returns (uint256 amountOut) {
        // Simple mock swap - just transfer tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Mock 1:1 swap for testing
        amountOut = amountIn;
        
        // Would normally swap, but for testing just return the input amount
        return amountOut;
    }
    
    // Mock add liquidity function
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to
    ) external returns (uint256 liquidity) {
        // Mock liquidity addition
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        
        return amountA + amountB; // Mock liquidity amount
    }
    
    // Receive function for ETH
    receive() external payable {
        emit TokenReceived(address(0), msg.value, msg.sender);
    }
    
    // Fallback for unknown calls
    fallback() external payable {
        emit MockFunctionCalled(msg.sender);
    }
    
    // Helper to check token balances in contract
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}