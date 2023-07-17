// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Interface/ICampaignTreasury.sol";
import "./Interface/ICampaignInfo.sol";

contract CampaignTreasury is ICampaignTreasury {
    address public immutable registry;
    address public immutable infoAddress;
    bytes32 public immutable platformId;
    uint256 constant percentDivider = 10000;
    uint256 public pledgedAmount;
    uint256 public platformFeePercent;

    constructor(
        address _registryAddress,
        address _infoAddress,
        bytes32 _platformId
    ) {
        registry = _registryAddress;
        infoAddress = _infoAddress;
        platformId = _platformId;
    }

    modifier onlyCampaignInfo() {
        require(
            msg.sender == infoAddress,
            "CampaignTreasury: Caller is not CampaignInfo contract"
        );
        _;
    }

    function getplatformId() public view returns (bytes32) {
        return platformId;
    }

    function getplatformFeePercent() public view returns (uint256) {
        return platformFeePercent;
    }

    function getplatformFee() public view returns (uint256) {
        return (pledgedAmount * platformFeePercent) / percentDivider;
    }

    function getTotalCollectableByCreator() public view returns (uint256) {
        return pledgedAmount - getplatformFee();
    }

    function getPledgedAmount() public view returns (uint256) {
        return pledgedAmount;
    }

    function pledgeInFiat(uint256 amount) external {
        pledgedAmount += amount;
    }

    function setplatformFeePercent(uint256 _platformFeePercent) external {
        platformFeePercent = _platformFeePercent;
    }

    function raisedBalance() external view override returns (uint256) {}

    function currentBalance() external view override returns (uint256) {
        return IERC20(ICampaignInfo(infoAddress).token()).balanceOf(address(this));
    }
}