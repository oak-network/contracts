# DataRegistryKeys
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/constants/DataRegistryKeys.sol)

**Title:**
DataRegistryKeys

Centralized storage for all dataRegistry keys used in GlobalParams

This library provides a single source of truth for all dataRegistry keys
to ensure consistency across contracts and prevent key collisions.


## Constants
### BUFFER_TIME

```solidity
bytes32 public constant BUFFER_TIME = keccak256("bufferTime")
```


### MAX_PAYMENT_EXPIRATION

```solidity
bytes32 public constant MAX_PAYMENT_EXPIRATION = keccak256("maxPaymentExpiration")
```


### CAMPAIGN_LAUNCH_BUFFER

```solidity
bytes32 public constant CAMPAIGN_LAUNCH_BUFFER = keccak256("campaignLaunchBuffer")
```


### MINIMUM_CAMPAIGN_DURATION

```solidity
bytes32 public constant MINIMUM_CAMPAIGN_DURATION = keccak256("minimumCampaignDuration")
```


## Functions
### scopedToPlatform

Generates a namespaced registry key scoped to a specific platform.


```solidity
function scopedToPlatform(bytes32 baseKey, bytes32 platformHash) internal pure returns (bytes32 platformKey);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseKey`|`bytes32`|The base registry key.|
|`platformHash`|`bytes32`|The identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`platformKey`|`bytes32`|The platform-scoped registry key.|


