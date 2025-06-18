# ITreasuryFactory
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ba93df0a979ce4ef420098855e6b4bfadbb6ecd/src/interfaces/ITreasuryFactory.sol)

*Interface for the TreasuryFactory contract, which registers, approves, and deploys treasury clones.*


## Functions
### registerTreasuryImplementation

Registers a treasury implementation for a given platform.

*Callable only by the platform admin.*


```solidity
function registerTreasuryImplementation(bytes32 platformHash, uint256 implementationId, address implementation)
    external;
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
function approveTreasuryImplementation(bytes32 platformHash, uint256 implementationId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier.|
|`implementationId`|`uint256`|The ID of the implementation to approve.|


### disapproveTreasuryImplementation

Disapproves a previously approved treasury implementation.


```solidity
function disapproveTreasuryImplementation(address implementation) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|The address of the implementation to disapprove.|


### removeTreasuryImplementation

Removes a registered treasury implementation from a platform.


```solidity
function removeTreasuryImplementation(bytes32 platformHash, uint256 implementationId) external;
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
) external returns (address clone);
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


## Events
### TreasuryFactoryTreasuryDeployed
*Emitted when a new treasury is deployed.*


```solidity
event TreasuryFactoryTreasuryDeployed(
    bytes32 indexed platformHash, uint256 indexed implementationId, address indexed infoAddress, address treasuryAddress
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier.|
|`implementationId`|`uint256`|The ID of the approved implementation.|
|`infoAddress`|`address`|The campaign info address linked to the treasury.|
|`treasuryAddress`|`address`|The deployed treasury address.|

