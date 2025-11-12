# ICampaignTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/fbdbad195ebe6c636608bb8168723963b1f37dd9/src/interfaces/ICampaignTreasury.sol)

An interface for managing campaign treasury contracts.


## Functions
### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() external;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() external;
```

### claimRefund

Claims a refund for a specific token ID.


```solidity
function claimRefund(uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The unique identifier of the refundable token.|


### getplatformHash

Retrieves the platform identifier associated with the treasury.


```solidity
function getplatformHash() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The platform identifier as a bytes32 value.|


### getplatformFeePercent

Retrieves the platform fee percentage for the treasury.


```solidity
function getplatformFeePercent() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The platform fee percentage as a uint256 value.|


### getRaisedAmount

Retrieves the total raised amount in the treasury.


```solidity
function getRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total raised amount as a uint256 value.|


### getLifetimeRaisedAmount

Retrieves the lifetime raised amount in the treasury (never decreases with refunds).


```solidity
function getLifetimeRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The lifetime raised amount as a uint256 value.|


### getRefundedAmount

Retrieves the total refunded amount in the treasury.


```solidity
function getRefundedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total refunded amount as a uint256 value.|


### cancelled

Checks if the treasury has been cancelled.


```solidity
function cancelled() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the treasury is cancelled, false otherwise.|


