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

    function contribute(address contributor, uint256 amount) public {
        IERC20(ICampaignInfo(info).token()).transferFrom(
            contributor,
            address(this),
            amount
        );
        raisedBalance += amount;
    }

    function collect() public {
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
