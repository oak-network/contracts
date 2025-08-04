# ICampaignPaymentTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/4076c45194ab23360a65e56402b026ef44f70a42/src/interfaces/ICampaignPaymentTreasury.sol)

An interface for managing campaign payment treasury contracts.


## Functions
### createPayment

Creates a new payment entry with the specified details.


```solidity
function createPayment(bytes32 paymentId, address buyerAddress, bytes32 itemId, uint256 amount, uint256 expiration)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|A unique identifier for the payment.|
|`buyerAddress`|`address`|The address of the buyer initiating the payment.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`amount`|`uint256`|The amount to be paid for the item.|
|`expiration`|`uint256`|The timestamp after which the payment expires.|


### cancelPayment

Cancels an existing payment with the given payment ID.


```solidity
function cancelPayment(bytes32 paymentId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to cancel.|


### confirmPayment

Confirms and finalizes the payment associated with the given payment ID.


```solidity
function confirmPayment(bytes32 paymentId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to confirm.|


### confirmPaymentBatch

Confirms and finalizes multiple payments in a single transaction.


```solidity
function confirmPaymentBatch(bytes32[] calldata paymentIds) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique payment identifiers to be confirmed.|


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

Claims a refund for a specific payment ID.


```solidity
function claimRefund(bytes32 paymentId, address refundAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


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


### getAvailableRaisedAmount

Retrieves the currently available raised amount in the treasury.


```solidity
function getAvailableRaisedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current available raised amount as a uint256 value.|


