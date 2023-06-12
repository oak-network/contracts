// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract CampaignContainers {
    struct Container {
        uint256[] items;
        uint256[] itemQuantity;
        uint256 value;
        bool isRewardTier;
    }

    mapping(address => mapping (bytes32 => Container)) public containers;

    function addContainer(
        address creator,
        bytes32 id,
        Container memory container
    ) public {
        containers[creator][id] = container;
    }
}
