# GlobalParamsStorage
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/storage/GlobalParamsStorage.sol)

**Title:**
GlobalParamsStorage

Storage contract for GlobalParams using ERC-7201 namespaced storage

This contract contains the storage layout and accessor functions for GlobalParams


## Constants
### GLOBAL_PARAMS_STORAGE_LOCATION

```solidity
bytes32 private constant GLOBAL_PARAMS_STORAGE_LOCATION =
    0xcab368c4291c205bbe63a595130eb08714925d02705f410a55bf1a45b8ddaf00
```


## Functions
### _getGlobalParamsStorage


```solidity
function _getGlobalParamsStorage() internal pure returns (Storage storage $);
```

## Structs
### LineItemType
Line item type configuration


```solidity
struct LineItemType {
    bool exists;
    string label;
    bool countsTowardGoal;
    bool applyProtocolFee;
    bool canRefund;
    bool instantTransfer;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`exists`|`bool`|Whether this line item type exists and is active|
|`label`|`string`|The label identifier for the line item type (e.g., "shipping_fee")|
|`countsTowardGoal`|`bool`|Whether this line item counts toward the campaign goal|
|`applyProtocolFee`|`bool`|Whether this line item is included in protocol fee calculation|
|`canRefund`|`bool`|Whether this line item can be refunded|
|`instantTransfer`|`bool`|Whether this line item amount can be instantly transferred|

### Storage
**Note:**
storage-location: erc7201:oaknetwork.storage.GlobalParams


```solidity
struct Storage {
    address protocolAdminAddress;
    uint256 protocolFeePercent;
    mapping(bytes32 => bool) platformIsListed;
    mapping(bytes32 => address) platformAdminAddress;
    mapping(bytes32 => uint256) platformFeePercent;
    mapping(bytes32 => bytes32) platformDataOwner;
    mapping(bytes32 => bool) platformData;
    mapping(bytes32 => bytes32) dataRegistry;
    mapping(bytes32 => address[]) currencyToTokens;
    // Platform-specific line item types: mapping(platformHash => mapping(typeId => LineItemType))
    mapping(bytes32 => mapping(bytes32 => LineItemType)) platformLineItemTypes;
    mapping(bytes32 => uint256) platformClaimDelay;
    // Platform adapter (trusted forwarder) for ERC-2771 meta-transactions: mapping(platformHash => adapterAddress)
    mapping(bytes32 => address) platformAdapter;
    Counters.Counter numberOfListedPlatforms;
}
```

