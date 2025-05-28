# ItemRegistry
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ac353e6507e46c7ee7bc7cb49a3fb20dfde2b56/src/utils/ItemRegistry.sol)

**Inherits:**
[IItem](/src/interfaces/IItem.sol/interface.IItem.md), Context

*A contract that manages the registration and retrieval of items.*


## State Variables
### Items

```solidity
mapping(address => mapping(bytes32 => Item)) private Items;
```


## Functions
### getItem

Retrieves the attributes of an item owned by a specific address.


```solidity
function getItem(address owner, bytes32 itemId) external view override returns (Item memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the item's owner.|
|`itemId`|`bytes32`|The unique identifier of the item.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Item`|item The attributes of the item as an `Item` struct.|


### addItem

Adds a new item with the given attributes.


```solidity
function addItem(bytes32 itemId, Item calldata item) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`bytes32`|The unique identifier of the item.|
|`item`|`Item`|The attributes of the item as an `Item` struct.|


### addItemsBatch

Adds multiple items in a batch.


```solidity
function addItemsBatch(bytes32[] calldata itemIds, Item[] calldata items) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemIds`|`bytes32[]`|An array of unique item identifiers.|
|`items`|`Item[]`|An array of `Item` structs containing item attributes.|


## Events
### ItemAdded
*Emitted when a new item is added to the registry.*


```solidity
event ItemAdded(address indexed owner, bytes32 indexed itemId, Item item);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the item owner.|
|`itemId`|`bytes32`|The unique identifier of the item.|
|`item`|`Item`|The item details including actual weight, dimensions, category, and declared currency.|

## Errors
### ItemRegistryMismatchedArraysLength
*Thrown when the input arrays have mismatched lengths.*


```solidity
error ItemRegistryMismatchedArraysLength();
```

