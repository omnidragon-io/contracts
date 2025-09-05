// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRouter
 * @notice Unified router interface supporting multiple DEX protocols
 * @dev Combines common functionality from Uniswap V2/V3, Algebra, Shadow Finance
 */
interface IRouter {
    // ============ Structs ============
    
    // For V3-style routers (Algebra, UniV3)
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }
    
    // For Solidly-style routers (Shadow Finance)
    struct Route {
        address from;
        address to;
        bool stable;  // false for volatile pairs
    }
    
    // ============ V2-Style Functions ============
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view returns (uint[] memory amounts);
    
    // ============ V3-Style Functions ============
    
    function exactInputSingle(ExactInputSingleParams calldata params) 
        external payable returns (uint256 amountOut);
    
    // ============ Solidly-Style Functions ============
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function getAmountsOut(uint256 amountIn, Route[] calldata routes)
        external view returns (uint256[] memory amounts);
        
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    
    // ============ Common View Functions ============
    
    function factory() external view returns (address);
}
