// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./CampaignRegistry.sol";
import "./CampaignInfo.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CampaignTreasury {
    address registryAddress;
    address infoAddress;
    bytes32 platformId;
    uint256 pledgedAmount;
    uint256 platformFeePercent;
    uint256 constant percentDivider = 10000;

    constructor(
        address _registryAddress,
        address _infoAddress,
        bytes32 _platformId
    ) {
        registryAddress = _registryAddress;
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

    function setplatformFeePercent(uint256 _platformFeePercent) public {
        platformFeePercent = _platformFeePercent;
    }

    function setPledgedAmount(uint256 _pledgedAmount) public {
        require(
            CampaignRegistry(registryAddress).getOracleAddress() == msg.sender
        );
        pledgedAmount = _pledgedAmount;
    }

    function disburseFeeToPlatform(
        address _platform,
        address _token,
        uint256 _amount
    ) public onlyCampaignInfo {
        IERC20(_token).transfer(_platform, _amount);
    }
}
