// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Interface/ICampaignTreasury.sol";
import "../Interface/ICampaignInfo.sol";

contract KeepWhatsRaised is ICampaignTreasury {

    address public immutable registry;
    address public immutable info;
    bytes32 public immutable platform;
    uint256 constant percentDivider = 10000; // @audit-issue unused percentDivider variable
    uint256 public pledgedAmount; // @audit-info if pledgedAmount value never change use constant or immutable
    uint256 public platformFeePercent; // @audit-info if platformFeePercent value never change use constant or immutable
    uint256 public raisedBalance;

    constructor(address _registry, address _info, bytes32 _platform) {
        // @audit-issue lacks zero address check
        registry = _registry;
        info = _info;
        platform = _platform;
    }

    // @audit Reentrancy Guard Issue
    function contribute(address contributor, uint256 amount) external {
        // @audit-issue lacks parameter filtering like zero address checking
        bool success = IERC20(ICampaignInfo(info).token()).transferFrom(
            contributor,
            address(this),
            amount
        );
        require(success);
        raisedBalance += amount;
    }

    function collect() external {
        ICampaignInfo campaign = ICampaignInfo(info);
        IERC20(campaign.token()).transfer(campaign.creator(), currentBalance());
    }

    function getplatformId() external view override returns (bytes32) {}

    function getplatformFeePercent() external view override returns (uint256) {}

    function getplatformFee() external view override returns (uint256) {}

    // function raisedBalance() external view override returns (uint256) {}

    function currentBalance() public view override returns (uint256) {
        return IERC20(ICampaignInfo(info).token()).balanceOf(address(this));
    }
}
