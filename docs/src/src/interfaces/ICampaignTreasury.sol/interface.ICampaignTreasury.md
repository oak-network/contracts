# ICampaignTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/7ac353e6507e46c7ee7bc7cb49a3fb20dfde2b56/src/interfaces/ICampaignTreasury.sol)

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


