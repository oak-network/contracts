# IGlobalParams
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ac353e6507e46c7ee7bc7cb49a3fb20dfde2b56/src/interfaces/IGlobalParams.sol)

An interface for accessing and managing global parameters of the protocol.


## Functions
### checkIfPlatformIsListed

Checks if a platform is listed in the protocol.


```solidity
function checkIfPlatformIsListed(bytes32 _platformHash) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is listed; otherwise, false.|


### getPlatformAdminAddress

Retrieves the admin address of a platform.


```solidity
function getPlatformAdminAddress(bytes32 _platformHash) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The admin address of the platform.|


### getNumberOfListedPlatforms

Retrieves the number of listed platforms in the protocol.


```solidity
function getNumberOfListedPlatforms() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of listed platforms.|


### getProtocolAdminAddress

Retrieves the admin address of the protocol.


```solidity
function getProtocolAdminAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The admin address of the protocol.|


### getTokenAddress

Retrieves the address of the protocol's native token.


```solidity
function getTokenAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the native token.|


### getProtocolFeePercent

Retrieves the protocol fee percentage.


```solidity
function getProtocolFeePercent() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee percentage as a uint256 value.|


### getPlatformDataOwner

Retrieves the owner of platform-specific data.


```solidity
function getPlatformDataOwner(bytes32 platformDataKey) external view returns (bytes32 platformHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The key of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The platform identifier associated with the data.|


### getPlatformFeePercent

Retrieves the platform fee percentage for a specific platform.


```solidity
function getPlatformFeePercent(bytes32 platformHash) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The unique identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The platform fee percentage as a uint256 value.|


### checkIfPlatformDataKeyValid

Checks if a platform-specific data key is valid.


```solidity
function checkIfPlatformDataKeyValid(bytes32 platformDataKey) external view returns (bool isValid);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The key of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isValid`|`bool`|True if the data key is valid; otherwise, false.|


### updateProtocolAdminAddress

Updates the admin address of the protocol.


```solidity
function updateProtocolAdminAddress(address _protocolAdminAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_protocolAdminAddress`|`address`|The new admin address of the protocol.|


### updateTokenAddress

Updates the address of the protocol's native token.


```solidity
function updateTokenAddress(address _tokenAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenAddress`|`address`|The new address of the native token.|


### updateProtocolFeePercent

Updates the protocol fee percentage.


```solidity
function updateProtocolFeePercent(uint256 _protocolFeePercent) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_protocolFeePercent`|`uint256`|The new protocol fee percentage as a uint256 value.|


### updatePlatformAdminAddress

Updates the admin address of a platform.


```solidity
function updatePlatformAdminAddress(bytes32 _platformHash, address _platformAdminAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_platformHash`|`bytes32`|The unique identifier of the platform.|
|`_platformAdminAddress`|`address`|The new admin address of the platform.|


