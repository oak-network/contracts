// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignContainers {
    struct Container {
        uint256[] items;
        uint256[] itemQuantity;
        uint256 value;
        bool isRewardTier;
    }

    function getContainer(
        address creator,
        bytes32 id
    ) external view returns (uint256);
    function containerOwners(address key) external view returns (bytes32 value);

    function addContainer(
        address creator,
        bytes32 id,
        Container memory container
    ) external;
}
