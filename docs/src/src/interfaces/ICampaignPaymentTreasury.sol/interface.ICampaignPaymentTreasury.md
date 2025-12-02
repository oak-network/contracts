# ICampaignPaymentTreasury
[Git Source](https://github.com/oak-network/ccprotocol-contracts-internal/blob/be3636c015d0f78c20f6d8f0de7b678aaf6d8428/src/interfaces/ICampaignPaymentTreasury.sol)

An interface for managing campaign payment treasury contracts.


## Functions
### createPayment

Creates a new payment entry with the specified details.


```solidity
function createPayment(
    bytes32 paymentId,
    bytes32 buyerId,
    bytes32 itemId,
    address paymentToken,
    uint256 amount,
    uint256 expiration,
    LineItem[] calldata lineItems,
    ExternalFees[] calldata externalFees
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|A unique identifier for the payment.|
|`buyerId`|`bytes32`|The id of the buyer initiating the payment.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`paymentToken`|`address`|The token to use for the payment.|
|`amount`|`uint256`|The amount to be paid for the item.|
|`expiration`|`uint256`|The timestamp after which the payment expires.|
|`lineItems`|`LineItem[]`|Array of line items associated with this payment.|
|`externalFees`|`ExternalFees[]`|Array of external fee metadata captured for this payment (informational only).|


### createPaymentBatch

Creates multiple payment entries in a single transaction to prevent nonce conflicts.


```solidity
function createPaymentBatch(
    bytes32[] calldata paymentIds,
    bytes32[] calldata buyerIds,
    bytes32[] calldata itemIds,
    address[] calldata paymentTokens,
    uint256[] calldata amounts,
    uint256[] calldata expirations,
    LineItem[][] calldata lineItemsArray,
    ExternalFees[][] calldata externalFeesArray
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique identifiers for the payments.|
|`buyerIds`|`bytes32[]`|An array of buyer IDs corresponding to each payment.|
|`itemIds`|`bytes32[]`|An array of item identifiers corresponding to each payment.|
|`paymentTokens`|`address[]`|An array of tokens corresponding to each payment.|
|`amounts`|`uint256[]`|An array of amounts corresponding to each payment.|
|`expirations`|`uint256[]`|An array of expiration timestamps corresponding to each payment.|
|`lineItemsArray`|`LineItem[][]`|An array of line item arrays, one for each payment.|
|`externalFeesArray`|`ExternalFees[][]`|An array of external fee metadata arrays, one for each payment (informational only).|


### processCryptoPayment

Allows a buyer to make a direct crypto payment for an item.

*This function transfers tokens directly from the buyer's wallet and confirms the payment immediately.*


```solidity
function processCryptoPayment(
    bytes32 paymentId,
    bytes32 itemId,
    address buyerAddress,
    address paymentToken,
    uint256 amount,
    LineItem[] calldata lineItems,
    ExternalFees[] calldata externalFees
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`buyerAddress`|`address`|The address of the buyer making the payment.|
|`paymentToken`|`address`|The token to use for the payment.|
|`amount`|`uint256`|The amount to be paid for the item.|
|`lineItems`|`LineItem[]`|Array of line items associated with this payment.|
|`externalFees`|`ExternalFees[]`|Array of external fee metadata captured for this payment (informational only).|


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
function confirmPayment(bytes32 paymentId, address buyerAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to confirm.|
|`buyerAddress`|`address`|Optional buyer address to mint NFT to. Pass address(0) to skip NFT minting.|


### confirmPaymentBatch

Confirms and finalizes multiple payments in a single transaction.


```solidity
function confirmPaymentBatch(bytes32[] calldata paymentIds, address[] calldata buyerAddresses) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique payment identifiers to be confirmed.|
|`buyerAddresses`|`address[]`|Array of buyer addresses to mint NFTs to. Must match paymentIds length. Pass address(0) to skip NFT minting for specific payments.|


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

Claims a refund for non-NFT payments (payments without minted NFTs).

*Only callable by platform admin. Used for payments confirmed without a buyer address.*


```solidity
function claimRefund(bytes32 paymentId, address refundAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must NOT have an NFT).|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


### claimRefund

Claims a refund for NFT payments (payments with minted NFTs).

*Burns the NFT associated with the payment. Caller must have approved the treasury for the NFT.
Used for processCryptoPayment and confirmPayment (with buyer address) transactions.*


```solidity
function claimRefund(bytes32 paymentId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must have an NFT).|


### claimExpiredFunds

Allows platform admin to claim all remaining funds once the claim window has opened.


```solidity
function claimExpiredFunds() external;
```

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


### getPaymentData

Retrieves comprehensive payment data including payment info, token, line items, and external fees.


```solidity
function getPaymentData(bytes32 paymentId) external view returns (PaymentData memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`PaymentData`|A PaymentData struct containing all payment information.|


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


### getExpectedAmount

Retrieves the total expected (pending) amount in the treasury.

*This represents payments that have been created but not yet confirmed.*


```solidity
function getExpectedAmount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total expected amount as a uint256 value.|


### cancelled

Checks if the treasury has been cancelled.


```solidity
function cancelled() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the treasury is cancelled, false otherwise.|


## Structs
### PaymentLineItem
Represents a stored line item with its configuration snapshot.


```solidity
struct PaymentLineItem {
    bytes32 typeId;
    uint256 amount;
    string label;
    bool countsTowardGoal;
    bool applyProtocolFee;
    bool canRefund;
    bool instantTransfer;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`typeId`|`bytes32`|The type identifier of the line item.|
|`amount`|`uint256`|The amount of the line item.|
|`label`|`string`|The human-readable label of the line item type.|
|`countsTowardGoal`|`bool`|Whether this line item counts toward the campaign goal.|
|`applyProtocolFee`|`bool`|Whether protocol fee applies to this line item.|
|`canRefund`|`bool`|Whether this line item can be refunded.|
|`instantTransfer`|`bool`|Whether this line item is transferred instantly.|

### PaymentData
Comprehensive payment data structure containing all payment information.


```solidity
struct PaymentData {
    address buyerAddress;
    bytes32 buyerId;
    bytes32 itemId;
    uint256 amount;
    uint256 expiration;
    bool isConfirmed;
    bool isCryptoPayment;
    uint256 lineItemCount;
    address paymentToken;
    PaymentLineItem[] lineItems;
    ExternalFees[] externalFees;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`buyerAddress`|`address`|The address of the buyer who made the payment.|
|`buyerId`|`bytes32`|The ID of the buyer.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`amount`|`uint256`|The amount to be paid for the item (in token's native decimals).|
|`expiration`|`uint256`|The timestamp after which the payment expires.|
|`isConfirmed`|`bool`|Boolean indicating whether the payment has been confirmed.|
|`isCryptoPayment`|`bool`|Boolean indicating whether the payment is made using direct crypto payment.|
|`lineItemCount`|`uint256`|The number of line items associated with this payment.|
|`paymentToken`|`address`|The token address used for this payment.|
|`lineItems`|`PaymentLineItem[]`|Array of stored line items with their configuration snapshots.|
|`externalFees`|`ExternalFees[]`|Array of external fee metadata associated with this payment (informational only).|

### LineItem
Represents a line item in a payment.


```solidity
struct LineItem {
    bytes32 typeId;
    uint256 amount;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`typeId`|`bytes32`|The type identifier of the line item (must exist in GlobalParams).|
|`amount`|`uint256`|The amount of the line item (denominated in pledge token).|

### ExternalFees
Represents metadata about external fees associated with a payment.

*These values are informational only and do not affect treasury balances or transfers.*


```solidity
struct ExternalFees {
    bytes32 feeType;
    uint256 feeAmount;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`feeType`|`bytes32`|The type identifier of the external fee.|
|`feeAmount`|`uint256`|The amount of the external fee.|

