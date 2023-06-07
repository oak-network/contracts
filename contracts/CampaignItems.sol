// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract CampaignItems {
    struct Container {
        uint256[] items;
        uint256[] itemQuantity;
        uint256 value;
        bool isRewardTier;
    }

    mapping(bytes32 => Container) containers;
    mapping(address => bytes32) containerOwners;

    function addContainer(
        address creator,
        bytes32 id,
        Container memory container
    ) public {
        containers[id] = container;
        containerOwners[creator] = id;
    }
}
