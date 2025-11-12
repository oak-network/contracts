# GlobalParamsStorage
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/storage/GlobalParamsStorage.sol)

Storage contract for GlobalParams using ERC-7201 namespaced storage

This contract contains the storage layout and accessor functions for GlobalParams


## State Variables
### GLOBAL_PARAMS_STORAGE_LOCATION

```solidity
bytes32 private constant GLOBAL_PARAMS_STORAGE_LOCATION =
    0x83d0145f7c1378f10048390769ec94f999b3ba6d94904b8fd7251512962b1c00
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
storage-location: erc7201:ccprotocol.storage.GlobalParams


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
    Counters.Counter numberOfListedPlatforms;
}
```

