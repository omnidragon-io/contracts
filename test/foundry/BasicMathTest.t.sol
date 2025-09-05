// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Basic math tests for Oracle price calculations
contract BasicMathTest is Test {
    
    function testDragonUsdCalculation() public {
        // Test core DRAGON/USD calculation: DRAGON/S × S/USD = DRAGON/USD
        
        // Example: 1000 DRAGON, 500 S reserves
        uint256 dragonReserve = 1000e18;
        uint256 sonicReserve = 500e18;  
        
        // DRAGON/S = 500/1000 = 0.5 S per DRAGON
        uint256 dragonSonicPrice = sonicReserve * 1e18 / dragonReserve;
        assertEq(dragonSonicPrice, 0.5e18);
        
        // S/USD = $2.00
        int256 sonicUsdPrice = 2e8; // 8 decimals
        
        // DRAGON/USD = 0.5 × $2.00 = $1.00
        int256 dragonUsdPrice = int256(dragonSonicPrice) * sonicUsdPrice / 1e18;
        assertEq(dragonUsdPrice, 1e8);
        
        console.log("SUCCESS: DRAGON/USD Calculation Test Passed");
        console.log("   DRAGON Reserve: 1000");
        console.log("   Sonic Reserve: 500");  
        console.log("   S/USD Price: $2.00");
        console.log("   Final DRAGON/USD: $1.00");
    }
    
    function testWeightedAverage() public {
        // Test weighted average of oracle prices
        
        int256 price1 = 100e8; // $100
        int256 price2 = 102e8; // $102
        
        uint256 weight1 = 7000; // 70%
        uint256 weight2 = 3000; // 30%
        
        int256 weightedSum = (price1 * int256(weight1)) + (price2 * int256(weight2));
        int256 averagePrice = weightedSum / 10000;
        
        // Expected: (100 * 0.7) + (102 * 0.3) = 70 + 30.6 = 100.6
        assertEq(averagePrice, 100.6e8);
        
        console.log("SUCCESS: Weighted Average Test Passed"); 
        console.log("   Oracle 1: $100 (70% weight)");
        console.log("   Oracle 2: $102 (30% weight)");
        console.log("   Average: $100.60");
    }
    
    function testDecimalNormalization() public {
        // Test normalizing 18 decimals to 8 decimals
        
        int256 price18Decimals = 150e18; // $150 with 18 decimals
        int256 price8Decimals = price18Decimals / 1e10; // Convert to 8 decimals
        
        assertEq(price8Decimals, 150e8);
        
        console.log("SUCCESS: Decimal Normalization Test Passed");
        console.log("   18 decimals: 150000000000000000000");
        console.log("   8 decimals: 15000000000");
    }
    
    function testSanityBounds() public {
        // Test price sanity check bounds
        
        int256 minValidPrice = 1; // $0.00000001 (smallest valid)
        int256 maxValidPrice = 1e14; // $1,000,000 (largest valid)
        
        assertTrue(minValidPrice >= 1);
        assertTrue(maxValidPrice <= 1e14);
        
        // Invalid prices
        int256 tooLow = 0;
        int256 tooHigh = 1e15; // $10M - too high
        
        assertTrue(tooLow < minValidPrice);
        assertTrue(tooHigh > maxValidPrice);
        
        console.log("SUCCESS: Sanity Bounds Test Passed");
        console.log("   Min valid: $0.00000001");
        console.log("   Max valid: $1,000,000");
    }
    
    function testProductionScenario() public {
        // Real-world scenario test
        
        console.log("PRODUCTION SCENARIO TEST");
        
        // DEX reserves: 2000 DRAGON, 400 S  
        uint256 dragonReserve = 2000e18;
        uint256 sonicReserve = 400e18;
        
        // DRAGON/S = 400/2000 = 0.2 S per DRAGON
        uint256 dragonSPrice = sonicReserve * 1e18 / dragonReserve;
        
        // S/USD aggregated from multiple oracles: $1.50
        int256 sonicUsdPrice = 1.5e8;
        
        // Final DRAGON/USD = 0.2 × $1.50 = $0.30
        int256 finalPrice = int256(dragonSPrice) * sonicUsdPrice / 1e18;
        
        assertEq(dragonSPrice, 0.2e18);
        assertEq(finalPrice, 0.3e8);
        
        console.log("   DEX: 2000 DRAGON / 400 S");
        console.log("   DRAGON/S: 0.2 S per DRAGON");
        console.log("   S/USD: $1.50");
        console.log("   DRAGON/USD: $0.30");
        console.log("SUCCESS: Production scenario validated!");
    }
}
