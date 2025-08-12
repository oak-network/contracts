# IItem
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/56580a82da87af15808145e03ffc25bd15b6454b/src/interfaces/IItem.sol)

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
    uint256 actualWeight;
    uint256 height;
    uint256 width;
    uint256 length;
    bytes32 category;
    bytes32 declaredCurrency;
}
```

