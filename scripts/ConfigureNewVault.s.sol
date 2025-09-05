// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/DragonJackpotVault.sol";

contract ConfigureNewVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Addresses (update these)
        address vault = 0x...; // New DragonJackpotVault address
        address lotteryManager = 0x...; // OmniDragonLotteryManager address
        address oracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777; // OmniDragonOracle
        
        // Token addresses
        address WRAPPED_SONIC = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        address DRAGON = 0x...; // DRAGON token address
        
        DragonJackpotVault vaultContract = DragonJackpotVault(vault);
        
        console.log("Configuring DragonJackpotVault...");
        
        // 1. Authorize LotteryManager to pay jackpots
        vaultContract.authorizePayer(lotteryManager, true);
        console.log("✅ Authorized LotteryManager for payouts");
        
        // 2. Set up oracles for USD valuation
        vaultContract.setTokenUsdOracle(WRAPPED_SONIC, oracle);
        console.log("✅ Set wS/USD oracle");
        
        vaultContract.setTokenUsdOracle(DRAGON, oracle);
        console.log("✅ Set DRAGON/USD oracle");
        
        // 3. Verify configuration
        console.log("Payout authorization:", vaultContract.authorizedPayer(lotteryManager));
        console.log("wS oracle:", vaultContract.tokenUsdOracle(WRAPPED_SONIC));
        console.log("DRAGON oracle:", vaultContract.tokenUsdOracle(DRAGON));
        
        vm.stopBroadcast();
    }
}
