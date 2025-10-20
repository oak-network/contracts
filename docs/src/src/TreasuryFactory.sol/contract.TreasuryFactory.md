# TreasuryFactory
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts/blob/b6945e2b533f7d9aacb156ae915f6d1bb6b199de/src/TreasuryFactory.sol)

**Inherits:**
[ITreasuryFactory](/src/interfaces/ITreasuryFactory.sol/interface.ITreasuryFactory.md), [AdminAccessChecker](/src/utils/AdminAccessChecker.sol/abstract.AdminAccessChecker.md)


## State Variables
### implementationMap

```solidity
mapping(bytes32 => mapping(uint256 => address)) private implementationMap;
```


### approvedImplementations

```solidity
mapping(address => bool) private approvedImplementations;
```


## Functions
### constructor

Initializes the TreasuryFactory contract.

*This constructor sets the address of the GlobalParams contract as the admin.*


```solidity
constructor(IGlobalParams globalParams);
```

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

