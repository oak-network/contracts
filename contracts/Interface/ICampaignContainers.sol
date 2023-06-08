// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface ICampaignContainers {
    struct Container {
        uint256[] items;
        uint256[] itemQuantity;
        uint256 value;
        bool isRewardTier;
    }

    function addContainer(
        address creator,
        bytes32 id,
        Container memory container
    ) external;
}
