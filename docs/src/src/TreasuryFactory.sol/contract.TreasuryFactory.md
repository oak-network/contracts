# TreasuryFactory
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/TreasuryFactory.sol)

**Inherits:**
Initializable, [ITreasuryFactory](/src/interfaces/ITreasuryFactory.sol/interface.ITreasuryFactory.md), [AdminAccessChecker](/src/utils/AdminAccessChecker.sol/abstract.AdminAccessChecker.md), UUPSUpgradeable

Factory contract for creating treasury contracts

*UUPS Upgradeable contract with ERC-7201 namespaced storage*


## State Variables
### TREASURY_FACTORY_STORAGE_LOCATION

```solidity
bytes32 private constant TREASURY_FACTORY_STORAGE_LOCATION =
    0x96b7de8c171ef460648aea35787d043e89feb6b6de2623a1e6f17a91b9c9e900;
```


## Functions
### _getTreasuryFactoryStorage


```solidity
function _getTreasuryFactoryStorage() private pure returns (TreasuryFactoryStorage storage $);
```

### constructor

*Constructor that disables initializers to prevent implementation contract initialization*


```solidity
constructor();
```

### initialize

Initializes the TreasuryFactory contract.


```solidity
function initialize(IGlobalParams globalParams) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`globalParams`|`IGlobalParams`|The address of the GlobalParams contract|


### _authorizeUpgrade

*Function that authorizes an upgrade to a new implementation*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyProtocolAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|Address of the new implementation|


### registerTreasuryImplementation

Registers a treasury implementation for a given platform.

*Callable only by the platform admin.*


```solidity
function registerTreasuryImplementation(bytes32 platformHash, uint256 implementationId, address implementation)
    external
    override
    onlyPlatformAdmin(platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier.|
|`implementationId`|`uint256`|The ID to assign to the implementation.|
|`implementation`|`address`|The contract address of the implementation.|


### approveTreasuryImplementation

Approves a previously registered implementation.

*Callable only by the protocol admin.*


```solidity
function approveTreasuryImplementation(bytes32 platformHash, uint256 implementationId)
    external
    override
    onlyProtocolAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier.|
|`implementationId`|`uint256`|The ID of the implementation to approve.|


### disapproveTreasuryImplementation

Disapproves a previously approved treasury implementation.


```solidity
function disapproveTreasuryImplementation(address implementation) external override onlyProtocolAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|The address of the implementation to disapprove.|


### removeTreasuryImplementation

Removes a registered treasury implementation from a platform.


```solidity
function removeTreasuryImplementation(bytes32 platformHash, uint256 implementationId)
    external
    override
    onlyPlatformAdmin(platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier.|
|`implementationId`|`uint256`|The implementation ID to remove.|


### deploy

Deploys a treasury clone using an approved implementation.

*Callable only by the platform admin.*


```solidity
function deploy(
    bytes32 platformHash,
    address infoAddress,
    uint256 implementationId,
    string calldata name,
    string calldata symbol
) external override onlyPlatformAdmin(platformHash) returns (address clone);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier.|
|`infoAddress`|`address`|The address of the campaign info contract.|
|`implementationId`|`uint256`|The ID of the implementation to use.|
|`name`|`string`|The name of the treasury token.|
|`symbol`|`string`|The symbol of the treasury token.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`clone`|`address`|The address of the deployed treasury contract.|


## Errors
### TreasuryFactoryUnauthorized

```solidity
error TreasuryFactoryUnauthorized();
```

### TreasuryFactoryInvalidKey

```solidity
error TreasuryFactoryInvalidKey();
```

### TreasuryFactoryTreasuryCreationFailed

```solidity
error TreasuryFactoryTreasuryCreationFailed();
```

### TreasuryFactoryInvalidAddress

```solidity
error TreasuryFactoryInvalidAddress();
```

### TreasuryFactoryImplementationNotSet

```solidity
error TreasuryFactoryImplementationNotSet();
```

### TreasuryFactoryImplementationNotSetOrApproved

```solidity
error TreasuryFactoryImplementationNotSetOrApproved();
```

### TreasuryFactoryTreasuryInitializationFailed

```solidity
error TreasuryFactoryTreasuryInitializationFailed();
```

### TreasuryFactorySettingPlatformInfoFailed

```solidity
error TreasuryFactorySettingPlatformInfoFailed();
```

## Structs
### TreasuryFactoryStorage
**Note:**
storage-location: erc7201:ccprotocol.storage.TreasuryFactory


```solidity
struct TreasuryFactoryStorage {
    mapping(bytes32 => mapping(uint256 => address)) implementationMap;
    mapping(address => bool) approvedImplementations;
}
```

