// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "../Interface/IItem.sol";

contract ItemRegistry is IItem, Context {

    mapping (address => mapping (bytes32 => Item)) Items;

    function getItem(address owner, bytes32 itemId) external view returns (Item memory) {
        return Items[owner][itemId];
    } 

    function addItem(bytes32 itemId, Item calldata item) external {
        Items[_msgSender()][itemId] = item;
    }
}