// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {IItem} from "../interfaces/IItem.sol";

/**
 * @title ItemRegistry
 * @dev A contract that manages the registration and retrieval of items.
 */
contract ItemRegistry is IItem, Context {
    mapping(address => mapping(bytes32 => Item)) private Items;

    /**
     * @dev Emitted when a new item is added to the registry.
     * @param owner The address of the item owner.
     * @param itemId The unique identifier of the item.
     * @param item The item details including actual weight, dimensions, category, and declared currency.
     */
    event ItemAdded(address indexed owner, bytes32 indexed itemId, Item item);

    /**
     * @dev Thrown when the input arrays have mismatched lengths.
     */
    error ItemRegistryMismatchedArraysLength();

    /**
     * @inheritdoc IItem
     */
    function getItem(
        address owner,
        bytes32 itemId
    ) external view override returns (Item memory) {
        return Items[owner][itemId];
    }

    /**
     * @inheritdoc IItem
     */
    function addItem(bytes32 itemId, Item calldata item) external override {
        Items[_msgSender()][itemId] = item;
        emit ItemAdded(_msgSender(), itemId, item);
    }

    /**
     * @notice Adds multiple items in a batch.
     * @param itemIds An array of unique item identifiers.
     * @param items An array of `Item` structs containing item attributes.
     */
    function addItemsBatch(
        bytes32[] calldata itemIds,
        Item[] calldata items
    ) external {
        if (itemIds.length != items.length) {
            revert ItemRegistryMismatchedArraysLength();
        }

        for (uint256 i = 0; i < itemIds.length; i++) {
            bytes32 itemId = itemIds[i];
            Item calldata item = items[i];

            Items[_msgSender()][itemId] = item;
            emit ItemAdded(_msgSender(), itemId, item);
        }
    }
}
