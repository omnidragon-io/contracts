// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/DragonJackpotVault.sol";

contract QuickVaultSetup is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Your exact setup:
        address vault = 0x...; // Replace with deployed vault address
        DragonJackpotVault vaultContract = DragonJackpotVault(vault);
        
        // 1. Set token addresses (if not set in constructor)
        address wS = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        address pfwS36 = 0x924140B8FA4e609038Be15fB32D4eeFC5ED6DDE0;
        address pDRAGON = 0x093D10C1bBcaC9d2480c4Fe126721877Eb8e21A4;
        address DRAGON = 0x40f531123bce8962D9ceA52a3B150023bef488Ed;
        
        vaultContract.setTokens(wS, pfwS36, pDRAGON, DRAGON);
        
        // 2. Set oracles (must return TOKEN/USD at 1e18)
        address wsUsdOracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
        address dragonUsdOracle = 0x69c1E310B9AD8BeA139696Df55A8Cb32A9f00777;
        
        vaultContract.setTokenUsdOracle(wS, wsUsdOracle);
        vaultContract.setTokenUsdOracle(DRAGON, dragonUsdOracle);
        
        // 3. Authorize your lottery manager
        address omniDragonLotteryManager = 0x8D1f7305eE40F0d3bb06b601963681ED3119EC0a;
        vaultContract.authorizePayer(address(omniDragonLotteryManager), true);
        
        console.log("SUCCESS: Vault configured!");
        console.log("LotteryManager can now:");
        console.log("- uint256 cap = jackpotVault.getJackpotBalance(); // wS capacity only");
        console.log("- uint256 reward = (cap * rewardBps) / 10_000;");
        console.log("- jackpotVault.payJackpot(winner, reward); // pays wS only");
        
        vm.stopBroadcast();
    }
}
