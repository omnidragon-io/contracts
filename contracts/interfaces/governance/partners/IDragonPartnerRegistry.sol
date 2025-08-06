// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDragonPartnerRegistry
 * @dev Interface for managing Dragon ecosystem partners
 *
 * Partners are entities that can receive probability boosts through veDRAGON voting
 * Provides democratic selection of ecosystem partners and reward allocation
 *
 * https://x.com/sonicreddragon
 * https://t.me/sonicreddragon
 */
interface IDragonPartnerRegistry {
  // === Structs ===
  struct PartnerInfo {
    address partnerAddress;
    string name;
    string description;
    bool isActive;
    uint256 totalVotesReceived;
    uint256 registrationTime;
  }

  // === Events ===
  event PartnerRegistered(uint256 indexed partnerId, address indexed partner, string name);
  event PartnerActivated(uint256 indexed partnerId, address indexed partner);
  event PartnerDeactivated(uint256 indexed partnerId, address indexed partner);
  event PartnerUpdated(uint256 indexed partnerId, string name, string description);

  // === View Functions ===
  
  /**
   * @dev Get partner address by ID
   * @param partnerId Partner ID
   * @return Partner address
   */
  function partnerList(uint256 partnerId) external view returns (address);

  /**
   * @dev Check if a partner is active
   * @param partner Partner address
   * @return Whether the partner is active
   */
  function isPartnerActive(address partner) external view returns (bool);

  /**
   * @dev Get total number of registered partners
   * @return Number of partners
   */
  function getPartnerCount() external view returns (uint256);

  /**
   * @dev Get partner information by ID
   * @param partnerId Partner ID
   * @return Partner information struct
   */
  function getPartnerInfo(uint256 partnerId) external view returns (PartnerInfo memory);

  /**
   * @dev Get partner ID by address
   * @param partner Partner address
   * @return Partner ID (returns type(uint256).max if not found)
   */
  function getPartnerIdByAddress(address partner) external view returns (uint256);

  /**
   * @dev Get all active partners
   * @return Array of active partner IDs
   */
  function getActivePartners() external view returns (uint256[] memory);

  // === State Changing Functions ===

  /**
   * @dev Register a new partner
   * @param partner Partner address
   * @param name Partner name
   * @param description Partner description
   * @return partnerId The assigned partner ID
   */
  function registerPartner(
    address partner, 
    string calldata name, 
    string calldata description
  ) external returns (uint256 partnerId);

  /**
   * @dev Activate a partner
   * @param partnerId Partner ID to activate
   */
  function activatePartner(uint256 partnerId) external;

  /**
   * @dev Deactivate a partner
   * @param partnerId Partner ID to deactivate
   */
  function deactivatePartner(uint256 partnerId) external;

  /**
   * @dev Update partner information
   * @param partnerId Partner ID
   * @param name New partner name
   * @param description New partner description
   */
  function updatePartner(
    uint256 partnerId, 
    string calldata name, 
    string calldata description
  ) external;
}