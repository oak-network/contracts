// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "../interfaces/IItem.sol";

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
}
