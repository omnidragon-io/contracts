// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GaugeController
 * @dev Minimal veCRV-like gauge voting controller for directing weights per epoch
 */
contract GaugeController is Ownable {
  uint256 public constant WEEK = 7 days;

  // Epoch => total weight (1e18)
  mapping(uint256 => uint256) public epochTotalWeight;
  // Gauge => epoch => weight (1e18)
  mapping(bytes32 => mapping(uint256 => uint256)) public gaugeWeight;
  // User => epoch => last vote timestamp (limit one update per epoch)
  mapping(address => uint256) public userLastVoteEpoch;

  // Track gauges
  mapping(bytes32 => bool) public isGauge;

  event GaugeAdded(bytes32 indexed gauge);
  event Voted(address indexed user, bytes32[] gauges, uint256[] weightsBps, uint256 epochWeek);

  constructor() Ownable(msg.sender) {}

  function _currentEpoch() internal view returns (uint256) {
    return (block.timestamp / WEEK) * WEEK;
  }

  function addGauge(bytes32 gauge) external onlyOwner {
    require(!isGauge[gauge], "exists");
    isGauge[gauge] = true;
    emit GaugeAdded(gauge);
  }

  /**
   * @notice Vote for gauges with basis points weights (sum <= 10000)
   * @dev Reversible per epoch by re-voting; uses user's absolute influence via msg.sender only by relative BP.
   */
  function voteForGauges(bytes32[] calldata gauges, uint256[] calldata weightsBps) external {
    require(gauges.length == weightsBps.length && gauges.length > 0, "len");
    uint256 sum;
    for (uint256 i = 0; i < gauges.length; i++) {
      require(isGauge[gauges[i]], "gauge");
      sum += weightsBps[i];
    }
    require(sum <= 10000, "sum");

    uint256 epochWeek = _currentEpoch();
    require(userLastVoteEpoch[msg.sender] < epochWeek, "voted");
    userLastVoteEpoch[msg.sender] = epochWeek;

    // For simplicity, treat each user's vote as 1 unit total, distributed by BPS
    // Aggregate into epoch weights as 1e18 scaled
    uint256 addedTotal;
    for (uint256 i = 0; i < gauges.length; i++) {
      uint256 w = (1e18 * weightsBps[i]) / 10000;
      gaugeWeight[gauges[i]][epochWeek] += w;
      addedTotal += w;
    }
    epochTotalWeight[epochWeek] += addedTotal;
    emit Voted(msg.sender, gauges, weightsBps, epochWeek);
  }

  /**
   * @notice Relative weight for gauge at time t (1e18 scaled)
   */
  function getRelativeWeight(bytes32 gauge, uint256 t) external view returns (uint256) {
    uint256 epochWeek = (t / WEEK) * WEEK;
    uint256 total = epochTotalWeight[epochWeek];
    if (total == 0) return 0;
    uint256 gw = gaugeWeight[gauge][epochWeek];
    return (gw * 1e18) / total;
  }
}


