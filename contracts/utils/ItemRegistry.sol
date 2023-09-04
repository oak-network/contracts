// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "../interfaces/IItem.sol";

contract ItemRegistry is IItem, Context {
    mapping(address => mapping(bytes32 => Item)) private Items;

    event ItemAdded(address indexed owner, bytes32 indexed itemId, Item item);

    function getItem(
        address owner,
        bytes32 itemId
    ) external view override returns (Item memory) {
        return Items[owner][itemId];
    }

    function addItem(bytes32 itemId, Item calldata item) external override {
        Items[_msgSender()][itemId] = item;
        emit ItemAdded(_msgSender(), itemId, item);
    }
}
