# AdminAccessChecker
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/utils/AdminAccessChecker.sol)

**Inherits:**
Context

This abstract contract provides access control mechanisms to restrict the execution of specific functions
to authorized protocol administrators and platform administrators.

Updated to use ERC-7201 namespaced storage for upgradeable contracts


## Functions
### __AccessChecker_init

Internal initializer function for AdminAccessChecker


```solidity
function __AccessChecker_init(IGlobalParams globalParams) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`globalParams`|`IGlobalParams`|The IGlobalParams contract instance|


### _getGlobalParams

Returns the stored GLOBAL_PARAMS for internal use


```solidity
function _getGlobalParams() internal view returns (IGlobalParams);
```

### onlyProtocolAdmin

Modifier that restricts function access to protocol administrators only.
Users attempting to execute functions with this modifier must be the protocol admin.


```solidity
modifier onlyProtocolAdmin() ;
```

### onlyPlatformAdmin

Modifier that restricts function access to platform administrators of a specific platform.
Users attempting to execute functions with this modifier must be the platform admin for the given platform.


```solidity
modifier onlyPlatformAdmin(bytes32 platformHash) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


### _onlyProtocolAdmin

Internal function to check if the sender is the protocol administrator.
If the sender is not the protocol admin, it reverts with AdminAccessCheckerUnauthorized error.


```solidity
function _onlyProtocolAdmin() private view;
```

### _onlyPlatformAdmin

Internal function to check if the sender is the platform administrator for a specific platform.
If the sender is not the platform admin, it reverts with AdminAccessCheckerUnauthorized error.


```solidity
function _onlyPlatformAdmin(bytes32 platformHash) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|


## Errors
### AdminAccessCheckerUnauthorized
Throws when the caller is not authorized.


```solidity
error AdminAccessCheckerUnauthorized();
```

