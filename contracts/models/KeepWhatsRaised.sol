// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Interface/ICampaignTreasury.sol";
import "../Interface/ICampaignInfo.sol";

contract KeepWhatsRaised is ICampaignTreasury {
    address public immutable registry;
    address public immutable info;
    bytes32 public immutable platform;
    uint256 constant percentDivider = 10000;
    uint256 public pledgedAmount;
    uint256 public platformFeePercent;
    uint256 public raisedBalance;

    constructor(address _registry, address _info, bytes32 _platform) {
        registry = _registry;
        info = _info;
        platform = _platform;
    }

}
