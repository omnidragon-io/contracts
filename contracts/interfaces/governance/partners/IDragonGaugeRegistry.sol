// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDragonGaugeRegistry
 * @dev Interface for managing Dragon ecosystem partner gauges and metadata.
 * Aligns with existing registry implementation used by partner pool, factory,
 * fee distributor, and veDRAGON boost manager components.
 */
interface IDragonGaugeRegistry {
  // === View Functions ===
  function partnerList(uint256 index) external view returns (address);
  function isPartnerActive(address partner) external view returns (bool);
  function getPartnerCount() external view returns (uint256);

  // Detailed getters used across contracts
  function getPartnerDetails(
    address partnerAddress
  ) external view returns (string memory name, uint256 feeShare, uint256 probabilityBoost, bool isActive);

  function partners(
    address partnerAddress
  ) external view returns (string memory name, uint256 feeShare, uint256 probabilityBoost, bool isActive);

  function authorizedDistributors(address distributor) external view returns (bool);
  function isDistributorAuthorized(address distributor) external view returns (bool);
  function defaultProbabilityBoost() external view returns (uint256);
  function isWhitelistedPartner(address partner) external view returns (bool);
  function getPartnerBoost(address partner) external view returns (uint256);

  // === State-Changing Functions ===
  function addPartner(
    address partnerAddress,
    string memory name,
    uint256 feeShare,
    uint256 probabilityBoost
  ) external;

  function addPartnerWithDefaultBoost(
    address partnerAddress,
    string memory name,
    uint256 feeShare
  ) external;

  function updatePartner(
    address partnerAddress,
    string memory name,
    uint256 feeShare,
    uint256 probabilityBoost
  ) external;

  function updatePartnerWithDefaultBoost(
    address partnerAddress,
    string memory name,
    uint256 feeShare
  ) external;

  function deactivatePartner(address partnerAddress) external;
  function setDistributorAuthorization(address distributor, bool authorized) external;
  function setDefaultProbabilityBoost(uint256 boost) external;

  // Simplified registration helpers used by other components
  function registerPartner(address partner, uint256 boost) external;
  function removePartner(address partner) external;
}


