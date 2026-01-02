# DataRegistryKeys
[Git Source](https://github.com/oak-network/contracts/blob/0ce055a8ba31ca09404e9d09ecd2549534cbec61/src/constants/DataRegistryKeys.sol)

Centralized storage for all dataRegistry keys used in GlobalParams

This library provides a single source of truth for all dataRegistry keys
to ensure consistency across contracts and prevent key collisions.


## State Variables
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


