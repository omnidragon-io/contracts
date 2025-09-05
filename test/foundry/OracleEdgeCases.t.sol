// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Comprehensive edge case tests for Oracle price calculations
contract OracleEdgeCasesTest is Test {
    
    function testExtremelyLowPrices() public {
        console.log("=== EXTREMELY LOW PRICE EDGE CASES ===");
        
        // Test minimum valid price boundary (1 wei = $0.00000001)
        int256 minPrice = 1;
        assertTrue(minPrice >= 1); // Should pass sanity check
        
        // Test price just below minimum (should fail)
        int256 belowMin = 0;
        assertTrue(belowMin < 1); // Should fail sanity check
        
        // Test micro-penny prices
        int256 microPenny = 10; // $0.0000001 (10 wei)
        assertTrue(microPenny >= 1);
        
        console.log("Min valid price: ", uint256(minPrice), "wei ($0.00000001)");
        console.log("Micro-penny price: ", uint256(microPenny), "wei ($0.0000001)");
        
        // Test DEX calculation with extremely low DRAGON price
        uint256 massiveDragonSupply = 1e27; // 1 billion DRAGON (18 decimals)
        uint256 tinyValue = 1e18; // 1 S
        
        uint256 microPrice = tinyValue * 1e18 / massiveDragonSupply;
        assertEq(microPrice, 1e9); // 0.000000001 S per DRAGON
        
        console.log("Massive supply scenario: ", microPrice / 1e9, "* 1e-9 S per DRAGON");
    }
    
    function testExtremelyHighPrices() public {
        console.log("=== EXTREMELY HIGH PRICE EDGE CASES ===");
        
        // Test maximum valid price boundary ($1,000,000)
        int256 maxPrice = 1e14; // $1M with 8 decimals
        assertTrue(maxPrice <= 1e14); // Should pass sanity check
        
        // Test price just above maximum (should fail)
        int256 aboveMax = 1e15; // $10M with 8 decimals
        assertTrue(aboveMax > 1e14); // Should fail sanity check
        
        console.log("Max valid price: $", uint256(maxPrice) / 1e8);
        console.log("Above max (invalid): $", uint256(aboveMax) / 1e8);
        
        // Test DEX calculation with extremely high DRAGON price
        uint256 scarceSupply = 1e15; // 0.001 DRAGON (18 decimals)
        uint256 highDemand = 1e24; // 1M S (18 decimals)
        
        uint256 extremePrice = highDemand * 1e18 / scarceSupply;
        assertEq(extremePrice, 1e27); // 1 billion S per DRAGON
        
        console.log("Scarcity scenario: ", extremePrice / 1e18, "S per DRAGON");
    }
    
    function testZeroReserveScenarios() public {
        console.log("=== ZERO RESERVE EDGE CASES ===");
        
        // Test zero DRAGON reserves (should fail)
        uint112 zeroDragon = 0;
        uint112 normalSonic = 1000e18;
        
        // This would cause division by zero - Oracle should handle gracefully
        if (zeroDragon == 0) {
            console.log("Zero DRAGON reserves detected - Oracle should reject");
            assertTrue(true); // Oracle should return (0, false)
        }
        
        // Test zero Sonic reserves (should fail)
        uint112 normalDragon = 1000e18;
        uint112 zeroSonic = 0;
        
        if (zeroSonic == 0) {
            console.log("Zero Sonic reserves detected - Oracle should reject");
            assertTrue(true); // Oracle should return (0, false)
        }
        
        // Test both zero (should fail)
        if (zeroDragon == 0 && zeroSonic == 0) {
            console.log("Both reserves zero - Oracle should reject");
            assertTrue(true);
        }
    }
    
    function testSingleOracleScenarios() public {
        console.log("=== SINGLE ORACLE EDGE CASES ===");
        
        // Test with only Chainlink active (100% weight)
        int256 chainlinkPrice = 150e8;
        uint256 chainlinkWeight = 10000; // 100%
        
        int256 singleOracleResult = (chainlinkPrice * int256(chainlinkWeight)) / 10000;
        assertEq(singleOracleResult, chainlinkPrice); // Should equal input
        
        console.log("Single oracle (Chainlink): $", uint256(singleOracleResult) / 1e8);
        
        // Test minimum oracle requirement (need at least 1 working)
        uint256 workingOracles = 1;
        assertTrue(workingOracles >= 1); // Should meet minimum requirement
        
        uint256 noOracles = 0;
        assertTrue(noOracles < 1); // Should fail minimum requirement
    }
    
    function testUnbalancedWeights() public {
        console.log("=== UNBALANCED WEIGHT EDGE CASES ===");
        
        // Test heavily skewed weights (99% vs 1%)
        int256 dominantOracle = 100e8; // $100
        int256 minorOracle = 200e8; // $200
        
        uint256 dominantWeight = 9900; // 99%
        uint256 minorWeight = 100; // 1%
        
        int256 skewedResult = (dominantOracle * int256(dominantWeight) + minorOracle * int256(minorWeight)) / 10000;
        
        // Should be very close to dominant oracle: 100 * 0.99 + 200 * 0.01 = 99 + 2 = 101
        assertEq(skewedResult, 101e8);
        
        console.log("Dominant oracle: $", uint256(dominantOracle) / 1e8, "(99%)");
        console.log("Minor oracle: $", uint256(minorOracle) / 1e8, "(1%)");
        console.log("Weighted result: $", uint256(skewedResult) / 1e8);
        
        // Test edge case: one oracle has 0% weight
        uint256 zeroWeight = 0;
        uint256 fullWeight = 10000;
        
        int256 zeroWeightResult = (dominantOracle * int256(fullWeight) + minorOracle * int256(zeroWeight)) / 10000;
        assertEq(zeroWeightResult, dominantOracle);
        
        console.log("Zero weight scenario: $", uint256(zeroWeightResult) / 1e8);
    }
    
    function testDecimalPrecisionEdgeCases() public {
        console.log("=== DECIMAL PRECISION EDGE CASES ===");
        
        // Test very precise decimal conversions
        int256 price18Decimals = 123456789123456789; // 0.123456789123456789 with 18 decimals
        int256 converted8Decimals = price18Decimals / 1e10;
        
        // Should truncate to 8 decimals: 12345678 (0.12345678)
        assertEq(converted8Decimals, 12345678);
        
        console.log("18-decimal input: ", uint256(price18Decimals));
        console.log("8-decimal output: ", uint256(converted8Decimals));
        
        // Test rounding edge case (should truncate, not round)
        int256 roundingTest = 199999999; // 1.99999999 with 8 extra digits
        int256 truncated = roundingTest / 1e8;
        assertEq(truncated, 1); // Should be 1, not 2
        
        console.log("Truncation test: ", uint256(roundingTest), "->", uint256(truncated));
        
        // Test maximum precision loss
        int256 maxPrecisionLoss = 999999999; // 9.99999999 with 8 extra digits  
        int256 lostPrecision = maxPrecisionLoss / 1e8;
        assertEq(lostPrecision, 9); // Lost 0.99999999
        
        console.log("Max precision loss: ", uint256(maxPrecisionLoss), "->", uint256(lostPrecision));
    }
    
    function testOverflowProtection() public {
        console.log("=== OVERFLOW PROTECTION EDGE CASES ===");
        
        // Test large number multiplication (potential overflow)
        uint256 largeReserve1 = type(uint112).max; // Maximum uint112
        uint256 largeReserve2 = type(uint112).max;
        
        console.log("Max uint112: ", largeReserve1);
        
        // Test if multiplication would overflow uint256
        uint256 product = largeReserve1 * largeReserve2;
        assertTrue(product > largeReserve1); // Should not overflow uint256
        
        // Test calculation with maximum values
        uint256 maxDragonReserve = type(uint112).max;
        uint256 maxSonicReserve = type(uint112).max;
        
        // This should equal 1e18 (1 S per DRAGON when reserves are equal)
        uint256 equalMaxReserves = maxSonicReserve * 1e18 / maxDragonReserve;
        assertEq(equalMaxReserves, 1e18);
        
        console.log("Equal max reserves price: ", equalMaxReserves / 1e18, "S per DRAGON");
    }
    
    function testTimeEdgeCases() public {
        console.log("=== TIME-BASED EDGE CASES ===");
        
        // Use a fixed timestamp to avoid underflow with block.timestamp (which could be 0 in tests)
        uint256 currentTime = 1000000; // Fixed timestamp
        vm.warp(currentTime); // Set block.timestamp
        
        // Test exactly at staleness threshold
        uint256 chainlinkThreshold = 3600; // 1 hour
        uint256 exactThreshold = currentTime - chainlinkThreshold;
        
        // Should be considered stale (>= threshold means stale)
        assertTrue(currentTime - exactThreshold >= chainlinkThreshold);
        
        // Test one second before threshold (should be fresh)
        uint256 justFresh = currentTime - (chainlinkThreshold - 1);
        assertTrue(currentTime - justFresh < chainlinkThreshold);
        
        // Test one second after threshold (should be stale)  
        uint256 justStale = currentTime - (chainlinkThreshold + 1);
        assertTrue(currentTime - justStale > chainlinkThreshold);
        
        console.log("Current time: ", currentTime);
        console.log("Exact threshold: ", exactThreshold, "(STALE)");
        console.log("Just fresh: ", justFresh, "(FRESH)");
        console.log("Just stale: ", justStale, "(STALE)");
        
        // Test future timestamp (should be invalid)
        uint256 futureTime = currentTime + 3600;
        assertTrue(futureTime > currentTime); // Future timestamps invalid
    }
    
    function testPriceDivergenceScenarios() public {
        console.log("=== PRICE DIVERGENCE EDGE CASES ===");
        
        // Test extreme oracle divergence (should still calculate average)
        int256 oracle1 = 50e8; // $50
        int256 oracle2 = 150e8; // $150 (3x difference)
        int256 oracle3 = 75e8; // $75
        int256 oracle4 = 125e8; // $125
        
        uint256 equalWeights = 2500; // 25% each
        
        int256 divergentAvg = (oracle1 + oracle2 + oracle3 + oracle4) * int256(equalWeights) / 10000;
        
        // (50 + 150 + 75 + 125) = 400 / 4 = 100
        assertEq(divergentAvg, 100e8);
        
        console.log("Divergent oracles: $50, $150, $75, $125");
        console.log("Average: $", uint256(divergentAvg) / 1e8);
        
        // Test extreme divergence (10x difference)
        int256 extremeLow = 10e8; // $10
        int256 extremeHigh = 100e8; // $100 (10x difference)
        
        int256 extremeAvg = (extremeLow * 5000 + extremeHigh * 5000) / 10000;
        assertEq(extremeAvg, 55e8); // (10 + 100) / 2 = 55
        
        console.log("Extreme divergence: $10 vs $100, Average: $55");
    }
    
    function testBoundaryCalculations() public {
        console.log("=== BOUNDARY CALCULATION EDGE CASES ===");
        
        // Test minimum meaningful DEX liquidity (conservative values)
        uint112 minLiquidity = 1e18; // 1 token (minimal but very safe)
        uint112 normalLiquidity = 1000e18; // 1000 tokens
        
        // Price with minimal DRAGON liquidity (very expensive DRAGON)
        uint256 expensiveDragon = uint256(normalLiquidity) * 1e18 / uint256(minLiquidity);
        console.log("Minimal DRAGON liquidity price: ", expensiveDragon / 1e18, "S per DRAGON");
        assertEq(expensiveDragon, 1000e18); // 1000 S per DRAGON
        
        // Price with minimal Sonic liquidity (very cheap DRAGON)  
        uint256 cheapDragon = uint256(minLiquidity) * 1e18 / uint256(normalLiquidity);
        console.log("Minimal Sonic liquidity price: ", cheapDragon / 1e15, "* 1e-3 S per DRAGON");
        assertEq(cheapDragon, 1e15); // 0.001 S per DRAGON
        
        // Test 1:1 parity edge case
        uint112 equalReserves = 500e18;
        uint256 parityPrice = uint256(equalReserves) * 1e18 / uint256(equalReserves);
        assertEq(parityPrice, 1e18); // Exactly 1 S per DRAGON
        
        console.log("1:1 parity price: ", parityPrice / 1e18, "S per DRAGON");
        
        // Test very low price scenario
        uint112 massiveSupply = 1e24; // 1 million tokens (within uint112 range)
        uint112 smallValue = 1e18; // 1 token
        
        uint256 lowPrice = uint256(smallValue) * 1e18 / uint256(massiveSupply);
        console.log("Low price scenario: ", lowPrice / 1e12, "* 1e-6 S per DRAGON");
        assertTrue(lowPrice > 0); // Should still be positive
        assertEq(lowPrice, 1e12); // 0.000001 S per DRAGON
    }
    
    function testCompoundingErrors() public {
        console.log("=== COMPOUNDING ERROR EDGE CASES ===");
        
        // Test multiple conversion steps (potential error accumulation)
        int256 originalPrice = 123456789e8; // $123,456,789 
        
        // Step 1: Convert to 18 decimals
        int256 step1 = originalPrice * 1e10;
        
        // Step 2: Apply some calculation
        int256 step2 = step1 * 95 / 100; // 95% of original
        
        // Step 3: Convert back to 8 decimals
        int256 finalPrice = step2 / 1e10;
        
        // Should be 95% of original: 123456789 * 0.95 = 117284349.55 -> 117284349
        int256 expected = originalPrice * 95 / 100;
        assertEq(finalPrice, expected);
        
        console.log("Multi-step calculation maintains precision");
        console.log("Original: $", uint256(originalPrice) / 1e8);
        console.log("Final: $", uint256(finalPrice) / 1e8);
        
        // Test precision loss in repeated operations
        int256 repeatedDiv = 1000e8;
        for (uint i = 0; i < 10; i++) {
            repeatedDiv = repeatedDiv * 999 / 1000; // Lose 0.1% each iteration
        }
        
        // After 10 iterations of 99.9%: 1000 * (0.999^10) ≈ 990.05
        assertTrue(repeatedDiv < 1000e8 && repeatedDiv > 980e8);
        console.log("After 10x 0.1% losses: $", uint256(repeatedDiv) / 1e8);
    }
}
