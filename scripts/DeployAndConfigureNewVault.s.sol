// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/DragonJackpotVault.sol";

contract DeployAndConfigureNewVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // ============ TOKEN ADDRESSES ============
        address WRAPPED_SONIC = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        address PFWS36_SHARE_TOKEN = 0x924140B8FA4e609038Be15fB32D4eeFC5ED6DDE0; // ERC-4626 vault shares
        address PDRAGON = 0x093D10C1bBcaC9d2480c4Fe126721877Eb8e21A4; // ERC-4626 DRAGON pod shares
        address DRAGON = 0x40f531123bce8962D9ceA52a3B150023bef488Ed; // Underlying DRAGON token (FatFinger)
        
        // ============ ORACLE ADDRESSES ============
        address omniDragonOracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777; // Returns DRAGON/USD and wS/USD at 1e18
        
        // ============ LOTTERY MANAGER ============
        address lotteryManager = 0x8D1f7305eE40F0d3bb06b601963681ED3119EC0a; // Current deployed LotteryManager
        
        address owner = msg.sender;

        console.log("=== DEPLOYING NEW DRAGON JACKPOT VAULT ===");
        
        // 1. Deploy new vault
        DragonJackpotVault vault = new DragonJackpotVault(
            WRAPPED_SONIC,      // wS payout token
            PFWS36_SHARE_TOKEN, // pfwS-36 vault shares
            PDRAGON,            // pDRAGON vault shares  
            DRAGON,             // DRAGON underlying token
            owner               // owner
        );
        
        console.log("✅ DragonJackpotVault deployed at:", address(vault));
        
        // 2. Set oracles for USD valuation (must return TOKEN/USD at 1e18)
        console.log("\n=== CONFIGURING ORACLES ===");
        
        vault.setTokenUsdOracle(WRAPPED_SONIC, omniDragonOracle);
        console.log("✅ Set wS/USD oracle:", omniDragonOracle);
        
        vault.setTokenUsdOracle(DRAGON, omniDragonOracle);
        console.log("✅ Set DRAGON/USD oracle:", omniDragonOracle);
        
        // 3. Authorize lottery manager for payouts
        console.log("\n=== AUTHORIZING LOTTERY MANAGER ===");
        
        vault.authorizePayer(lotteryManager, true);
        console.log("✅ Authorized LotteryManager for payouts:", lotteryManager);
        
        // 4. Verify configuration
        console.log("\n=== VERIFICATION ===");
        console.log("Vault owner:", vault.owner());
        console.log("wS token:", vault.WRAPPED_SONIC());
        console.log("pfwS36 token:", vault.PFWS36_SHARE_TOKEN());
        console.log("pDRAGON token:", vault.PDRAGON());
        console.log("DRAGON token:", vault.DRAGON());
        console.log("wS oracle:", vault.tokenUsdOracle(WRAPPED_SONIC));
        console.log("DRAGON oracle:", vault.tokenUsdOracle(DRAGON));
        console.log("LotteryManager authorized:", vault.authorizedPayer(lotteryManager));
        
        // 5. Test view functions
        console.log("\n=== TESTING VIEW FUNCTIONS ===");
        uint256 wsCapacity = vault.getJackpotCapacityWS();
        uint256 jackpotBalance = vault.getJackpotBalance();
        uint256 usdValue = vault.getJackpotUsd1e6();
        
        console.log("wS Capacity:", wsCapacity);
        console.log("Jackpot Balance (same as capacity):", jackpotBalance);
        console.log("USD Value (1e6):", usdValue);
        
        vm.stopBroadcast();
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Update LotteryManager to use new vault:", address(vault));
        console.log("2. Transfer assets from old vault to new vault");
        console.log("3. Test payout functionality");
    }
}
