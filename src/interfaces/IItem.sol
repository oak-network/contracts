// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IItem
 * @notice An interface for managing items and their attributes.
 */
interface IItem {
    /**
     * @notice Represents the attributes of an item.
     */
    struct Item {
        uint256 actualWeight; // The actual weight of the item.
        uint256 height; // The height of the item.
        uint256 width; // The width of the item.
        uint256 length; // The length of the item.
        bytes32 category; // The category of the item.
        bytes32 declaredCurrency; // The declared currency of the item.
    }

    /**
     * @notice Retrieves the attributes of an item owned by a specific address.
     * @param owner The address of the item's owner.
     * @param itemId The unique identifier of the item.
     * @return item The attributes of the item as an `Item` struct.
     */
    function getItem(
        address owner,
        bytes32 itemId
    ) external view returns (Item memory item);

    /**
     * @notice Adds a new item with the given attributes.
     * @param itemId The unique identifier of the item.
     * @param item The attributes of the item as an `Item` struct.
     */
    function addItem(bytes32 itemId, Item calldata item) external;
}
