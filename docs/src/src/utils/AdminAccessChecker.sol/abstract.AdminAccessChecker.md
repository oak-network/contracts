# AdminAccessChecker
[Git Source](https://github.com/ccprotocol/campaign-utils-contracts-aggregator/blob/79d78188e565502f83e2c0309c9a4ea3b35cee91/src/utils/AdminAccessChecker.sol)

*This abstract contract provides access control mechanisms to restrict the execution of specific functions
to authorized protocol administrators and platform administrators.*


## State Variables
### GLOBAL_PARAMS

```solidity
IGlobalParams internal immutable GLOBAL_PARAMS;
```


## Functions
### constructor

*Constructor to initialize the contract with the address of the global parameters contract.*


```solidity
constructor(IGlobalParams globalParams);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`globalParams`|`IGlobalParams`|The address of the IGlobalParams contract.|


### onlyProtocolAdmin

*Modifier that restricts function access to protocol administrators only.
Users attempting to execute functions with this modifier must be the protocol admin.*


```solidity
modifier onlyProtocolAdmin();
```

### onlyPlatformAdmin

*Modifier that restricts function access to platform administrators of a specific platform.
Users attempting to execute functions with this modifier must be the platform admin for the given platform.*


```solidity
modifier onlyPlatformAdmin(bytes32 platformBytes);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The unique identifier of the platform.|


### _checkIfProtocolAdmin

*Internal function to check if the sender is the protocol administrator.
If the sender is not the protocol admin, it reverts with AdminAccessCheckerUnauthorized error.*


```solidity
function _checkIfProtocolAdmin() private view;
```

### _checkIfPlatformAdmin

*Internal function to check if the sender is the platform administrator for a specific platform.
If the sender is not the platform admin, it reverts with AdminAccessCheckerUnauthorized error.*


```solidity
function _checkIfPlatformAdmin(bytes32 platformBytes) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformBytes`|`bytes32`|The unique identifier of the platform.|


## Errors
### AdminAccessCheckerUnauthorized
*Throws when the caller is not authorized.*


```solidity
error AdminAccessCheckerUnauthorized();
```

