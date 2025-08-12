# ICampaignInfo
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/56580a82da87af15808145e03ffc25bd15b6454b/src/interfaces/ICampaignInfo.sol)

An interface for managing campaign information in a crowdfunding system.


## Functions
### owner

Returns the owner of the contract.


```solidity
function owner() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the contract owner.|


### checkIfPlatformSelected

Checks if a platform has been selected for the campaign.


```solidity
function checkIfPlatformSelected(bytes32 platformHash) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the platform is selected, false otherwise.|


### getTotalRaisedAmount

Retrieves the total amount raised in the campaign.


```solidity
function getTotalRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount raised in the campaign.|


### getProtocolAdminAddress

Retrieves the address of the protocol administrator.


```solidity
function getProtocolAdminAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the protocol administrator.|


### getPlatformAdminAddress

Retrieves the address of the platform administrator for a specific platform.


```solidity
function getPlatformAdminAddress(bytes32 platformHash) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the platform administrator.|


### getLaunchTime

Retrieves the campaign's launch time.


```solidity
function getLaunchTime() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign was launched.|


### getDeadline

Retrieves the campaign's deadline.


```solidity
function getDeadline() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the campaign ends.|


### getGoalAmount

Retrieves the campaign's funding goal amount.


```solidity
function getGoalAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The funding goal amount of the campaign.|


### getTokenAddress

Retrieves the address of the token used in the campaign.


```solidity
function getTokenAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the campaign's token.|


### getProtocolFeePercent

Retrieves the protocol fee percentage for the campaign.


```solidity
function getProtocolFeePercent() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee percentage applied to the campaign.|


### getPlatformFeePercent

Retrieves the platform fee percentage for a specific platform.


```solidity
function getPlatformFeePercent(bytes32 platformHash) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The platform fee percentage applied to the campaign on the platform.|


### getPlatformData

Retrieves platform-specific data for the campaign.


```solidity
function getPlatformData(bytes32 platformDataKey) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformDataKey`|`bytes32`|The bytes32 identifier of the platform-specific data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The platform-specific data associated with the given key.|


### getIdentifierHash

Retrieves the unique identifier hash of the campaign.


```solidity
function getIdentifierHash() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The bytes32 hash that uniquely identifies the campaign.|


### transferOwnership

Transfers ownership of the contract to a new owner.


```solidity
function transferOwnership(address newOwner) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOwner`|`address`|The address of the new contract owner.|


### updateLaunchTime

Updates the campaign's launch time.


```solidity
function updateLaunchTime(uint256 launchTime) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`launchTime`|`uint256`|The new launch timestamp.|


### updateDeadline

Updates the campaign's deadline.


```solidity
function updateDeadline(uint256 deadline) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deadline`|`uint256`|The new deadline timestamp.|


### updateGoalAmount

Updates the campaign's funding goal amount.


```solidity
function updateGoalAmount(uint256 goalAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`goalAmount`|`uint256`|The new funding goal amount.|


### updateSelectedPlatform

Updates the selection status of a platform for the campaign.

*It can only be called for a platform if its not approved i.e. the platform treasury is not deployed*


```solidity
function updateSelectedPlatform(
    bytes32 platformHash,
    bool selection,
    bytes32[] calldata platformDataKey,
    bytes32[] calldata platformDataValue
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`platformHash`|`bytes32`|The bytes32 identifier of the platform.|
|`selection`|`bool`|The new selection status (true or false).|
|`platformDataKey`|`bytes32[]`|An array of platform-specific data keys.|
|`platformDataValue`|`bytes32[]`|An array of platform-specific data values.|


### paused

*Returns true if the campaign is paused, and false otherwise.*


```solidity
function paused() external view returns (bool);
```

### cancelled

*Returns true if the campaign is cancelled, and false otherwise.*


```solidity
function cancelled() external view returns (bool);
```

