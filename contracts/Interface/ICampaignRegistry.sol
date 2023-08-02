// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignRegistry {
    function initialize(address _factoryAddress) external;

    // function owner() external view returns (address);

    function getFactoryAddress() external view returns (address);

    function getCampaignInfoAddress(
        string calldata identifier
    ) external view returns (address);

    function setCampaignInfoAddress(
        string calldata _identifier,
        address _campaignAddress
    ) external;
}
