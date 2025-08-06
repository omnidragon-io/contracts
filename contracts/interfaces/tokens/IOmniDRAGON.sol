// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IOmniDRAGON
 * @author 0xakita.eth
 * @dev Interface for the omniDRAGON LayerZero OFT V2 token with lottery integration
 * 
 * Features:
 * - LayerZero OFT V2 cross-chain functionality  
 * - Integrated lottery system for trading incentives
 * - 1inch Fusion+ integration bonuses
 * - Registry-based multi-chain configuration
 * - Vanity address deployment (0x69...7777)
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
interface IOmniDRAGON is IERC20 {
    
    /**
     * @dev Fee structure for buy/sell transactions
     */
    struct Fees {
        uint16 jackpot;    // Basis points for jackpot
        uint16 veDRAGON;   // Basis points for veDRAGON holders
        uint16 burn;       // Basis points to burn
        uint16 total;      // Total basis points
    }
    
    /**
     * @dev Control flags for the contract
     */
    struct ControlFlags {
        bool feesEnabled;
        bool tradingEnabled;
        bool initialMintCompleted;
        bool paused;
        bool emergencyMode;
    }
    
    /**
     * @dev Cross-chain transfer information
     */
    struct CrossChainTransfer {
        uint32 dstEid;
        address to;
        uint256 amount;
        uint256 fee;
        bytes extraOptions;
    }
    
    // Events
    event FeesUpdated(Fees newFees);
    event VaultUpdated(address indexed vault, string vaultType);
    event TradingEnabled(bool enabled);
    event FeesEnabled(bool enabled);
    event PairUpdated(address indexed pair, bool isListed);
    event LotteryManagerUpdated(address indexed newManager);
    event CrossChainTransferInitiated(
        uint32 indexed dstEid,
        address indexed to,
        uint256 amount,
        uint256 fee
    );
    event FeeDistributed(
        address indexed vault,
        uint256 amount,
        string category
    );
    event LotteryTriggered(
        address indexed trader,
        uint256 amount,
        uint256 tickets
    );
    event EmergencyModeToggled(bool enabled);
    
    // View functions
    function getFees() external view returns (Fees memory buyFees_, Fees memory sellFees_);
    function getControlFlags() external view returns (ControlFlags memory);
    function getDistributionAddresses() external view returns (address jackpot, address revenue);
    function jackpotVault() external view returns (address);
    function revenueDistributor() external view returns (address);
    function lotteryManager() external view returns (address);
    function registry() external view returns (address);
    function isPair(address account) external view returns (bool);
    function isExcludedFromFees(address account) external view returns (bool);
    function isExcludedFromMaxTransfer(address account) external view returns (bool);
    
    // Admin functions
    function updateVaults(address _jackpotVault, address _revenueDistributor) external;
    function setPair(address pair, bool isActive) external;
    function setExcludeFromFees(address account, bool excluded) external;
    function setExcludeFromMaxTransfer(address account, bool excluded) external;
    function updateFees(bool isBuy, uint16 _jackpot, uint16 _veDRAGON, uint16 _burn) external;
    function setLotteryManager(address _lotteryManager) external;
    function toggleTrading() external;
    function toggleFees() external;
    function togglePause() external;
    function toggleEmergencyMode() external;
    function emergencyWithdrawNative(uint256 amount) external;
    function emergencyWithdrawToken(address token, uint256 amount) external;
    
    // Additional functions
    function registerMe() external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}