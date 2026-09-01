# ItemRegistry
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/utils/ItemRegistry.sol)

**Inherits:**
[IItem](/src/interfaces/IItem.sol/interface.IItem.md), Context

**Title:**
ItemRegistry

A contract that manages the registration and retrieval of items.


## State Variables
### Items

```solidity
mapping(address => mapping(bytes32 => Item)) private Items
```


### s_itemExists

```solidity
mapping(address => mapping(bytes32 => bool)) private s_itemExists
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


### removeItem

Removes an item from the caller's registry.


```solidity
function removeItem(bytes32 itemId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`bytes32`|The unique identifier of the item to remove.|


## Events
### ItemAdded
Emitted when a new item is added to the registry.


```solidity
event ItemAdded(address indexed owner, bytes32 indexed itemId, Item item);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the item owner.|
|`itemId`|`bytes32`|The unique identifier of the item.|
|`item`|`Item`|The item details including actual weight, dimensions, category, and declared currency.|

### ItemRemoved
Emitted when an item is removed from the registry.


```solidity
event ItemRemoved(address indexed owner, bytes32 indexed itemId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the item owner.|
|`itemId`|`bytes32`|The unique identifier of the item.|

## Errors
### ItemRegistryMismatchedArraysLength
Thrown when the input arrays have mismatched lengths.


```solidity
error ItemRegistryMismatchedArraysLength();
```

### ItemRegistryItemAlreadyExists
Thrown when attempting to add an item that already exists (overwrite not allowed).


```solidity
error ItemRegistryItemAlreadyExists(bytes32 itemId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`bytes32`|The item identifier that already exists.|

### ItemRegistryDuplicateItemId
Thrown when the batch contains duplicate itemIds.


```solidity
error ItemRegistryDuplicateItemId(bytes32 itemId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`bytes32`|The duplicate item identifier.|

### ItemRegistryItemDoesNotExist
Thrown when attempting to remove an item that does not exist.


```solidity
error ItemRegistryItemDoesNotExist(bytes32 itemId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`bytes32`|The item identifier.|

