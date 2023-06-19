// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Interface/ICampaignTreasury.sol";

contract CampaignTreasury is ICampaignTreasury {
    address immutable registry;
    address immutable infoAddress;
    bytes32 immutable platformId;
    uint256 constant percentDivider = 10000;
    uint256 pledgedAmount;
    uint256 platformFeePercent;

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

    function disburseFeeToPlatform(
        address _platform,
        address _token,
        uint256 _amount
    ) external onlyCampaignInfo {
        IERC20(_token).transfer(_platform, _amount);
    }

    function setPledgedAmount(uint256 _pledgedAmount) external override {}
}
