// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/lottery/OmniDragonLotteryManager.sol";

contract DeployLotteryManager is Script {
    // Registry address (same across all chains)
    address constant REGISTRY_ADDRESS = 0x6949936442425f4137807Ac5d269e6Ef66d50777;
    
    // VRF addresses (operational)
    address constant VRF_INTEGRATOR = 0x2BD68f5E956ca9789A7Ab7674670499e65140Bd5;
    address constant VRF_CONSUMER = 0x697a9d438a5b61ea75aa823f98a85efb70fd23d5; // Arbitrum only
    
    // Chain-specific configurations
    struct ChainConfig {
        uint256 chainId;
        string name;
        address omniDRAGON; // Will be deployed later
        address veDRAGON;   // Will be deployed later  
        address priceOracle; // Will be deployed later
    }
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get current chain ID
        uint256 currentChainId = block.chainid;
        ChainConfig memory config = getChainConfig(currentChainId);
        
        console.log("=== DEPLOYING OMNIDRAGON LOTTERY MANAGER ===");
        console.log("Network:", config.name);
        console.log("Chain ID:", config.chainId);
        console.log("Deployer:", deployer);
        console.log("Registry:", REGISTRY_ADDRESS);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy mock components (replace with real addresses when available)
        console.log("1. Deploying mock components...");
        
        // Mock Jackpot Distributor
        MockJackpotDistributor jackpotDistributor = new MockJackpotDistributor();
        console.log("   Mock JackpotDistributor deployed at:", address(jackpotDistributor));
        
        // Mock veDRAGON (simple ERC20 for now)
        MockToken veDRAGON = new MockToken("Voting Escrow DRAGON", "veDRAGON", 18);
        console.log("   Mock veDRAGON deployed at:", address(veDRAGON));
        
        // Mock Price Oracle
        MockPriceOracle priceOracle = new MockPriceOracle();
        console.log("   Mock PriceOracle deployed at:", address(priceOracle));
        
        // Step 2: Deploy DragonJackpotVault (optional for now)
        console.log("2. Deploying DragonJackpotVault...");
        DragonJackpotVault jackpotVault = new DragonJackpotVault();
        console.log("   DragonJackpotVault deployed at:", address(jackpotVault));
        
        // Step 3: Deploy OmniDragonLotteryManager
        console.log("3. Deploying OmniDragonLotteryManager...");
        OmniDragonLotteryManager lotteryManager = new OmniDragonLotteryManager(
            address(jackpotDistributor), // Use mock distributor
            address(veDRAGON),
            address(priceOracle),
            config.chainId
        );
        console.log("   OmniDragonLotteryManager deployed at:", address(lotteryManager));
        
        // Step 4: Configure VRF integration
        console.log("4. Configuring VRF integration...");
        if (currentChainId == 146) { // Sonic
            lotteryManager.setVRFIntegrator(VRF_INTEGRATOR);
            console.log("   VRF Integrator set to:", VRF_INTEGRATOR);
        } else if (currentChainId == 42161) { // Arbitrum  
            lotteryManager.setVRFConsumer(VRF_CONSUMER);
            console.log("   VRF Consumer set to:", VRF_CONSUMER);
        }
        
        // Step 5: Set JackpotVault owner to LotteryManager
        console.log("5. Transferring JackpotVault ownership...");
        jackpotVault.transferOwnership(address(lotteryManager));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================");
        console.log("DragonJackpotVault:", address(jackpotVault));
        console.log("Mock veDRAGON:", address(veDRAGON));
        console.log("Mock PriceOracle:", address(priceOracle));
        console.log("OmniDragonLotteryManager:", address(lotteryManager));
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Deploy real veDRAGON and PriceOracle contracts");
        console.log("2. Update lottery manager with real addresses");
        console.log("3. Configure lottery parameters");
        console.log("4. Test lottery functionality with VRF");
        console.log("");
        console.log("VRF INTEGRATION:");
        console.log("- VRF system is operational and ready");
        console.log("- Lottery can now use cross-chain randomness");
        console.log("- Test with: lotteryManager.triggerInstantLottery()");
    }
    
    function getChainConfig(uint256 chainId) internal pure returns (ChainConfig memory) {
        if (chainId == 146) { // Sonic
            return ChainConfig({
                chainId: 146,
                name: "Sonic",
                omniDRAGON: address(0), // To be deployed
                veDRAGON: address(0),   // To be deployed
                priceOracle: address(0) // To be deployed
            });
        } else if (chainId == 42161) { // Arbitrum
            return ChainConfig({
                chainId: 42161,
                name: "Arbitrum",
                omniDRAGON: address(0), // To be deployed
                veDRAGON: address(0),   // To be deployed  
                priceOracle: address(0) // To be deployed
            });
        } else if (chainId == 1) { // Ethereum
            return ChainConfig({
                chainId: 1,
                name: "Ethereum",
                omniDRAGON: address(0), // To be deployed
                veDRAGON: address(0),   // To be deployed
                priceOracle: address(0) // To be deployed
            });
        } else {
            revert("Unsupported chain");
        }
    }
}

// Mock contracts for initial deployment
contract MockToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = 1000000 * 10**_decimals;
        balanceOf[msg.sender] = totalSupply;
    }
    
    // Mock methods for veDRAGON interface
    function lockedEnd(address) external pure returns (uint256) {
        return block.timestamp + 365 days; // Mock 1 year lock
    }
}

contract MockPriceOracle {
    // Implement IOmniDragonPriceOracle interface
    function getAggregatedPrice() external pure returns (int256 price, bool success, uint256 timestamp) {
        return (100000000, true, block.timestamp); // $1.00 with 8 decimals
    }
    
    function getLatestPrice() external pure returns (int256 price, uint256 timestamp) {
        return (100000000, block.timestamp); // $1.00 with 8 decimals
    }
}

contract MockJackpotDistributor {
    uint256 public jackpotBalance = 1000 * 1e18; // Mock 1000 DRAGON tokens
    
    // Implement IDragonJackpotDistributor interface
    function getCurrentJackpot() external view returns (uint256) {
        return jackpotBalance;
    }
    
    function distributeJackpot(address winner, uint256 amount) external {
        require(amount <= jackpotBalance, "Insufficient jackpot");
        jackpotBalance -= amount;
        // In real implementation, would transfer tokens to winner
        console.log("Jackpot distributed to", winner, "amount:", amount);
    }
}
