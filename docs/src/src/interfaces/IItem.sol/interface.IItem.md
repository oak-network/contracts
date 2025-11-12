# IItem
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/interfaces/IItem.sol)

An interface for managing items and their attributes.


## Functions
### getItem

Retrieves the attributes of an item owned by a specific address.


```solidity
function getItem(address owner, bytes32 itemId) external view returns (Item memory item);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the item's owner.|
|`itemId`|`bytes32`|The unique identifier of the item.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`item`|`Item`|The attributes of the item as an `Item` struct.|


### addItem

Adds a new item with the given attributes.


```solidity
function addItem(bytes32 itemId, Item calldata item) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`bytes32`|The unique identifier of the item.|
|`item`|`Item`|The attributes of the item as an `Item` struct.|


## Structs
### Item
Represents the attributes of an item.


```solidity
struct Item {
    uint256 actualWeight; // The actual weight of the item.
    uint256 height; // The height of the item.
    uint256 width; // The width of the item.
    uint256 length; // The length of the item.
    bytes32 category; // The category of the item.
    bytes32 declaredCurrency; // The declared currency of the item.
}
```

