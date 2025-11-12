# TimeConstrainedPaymentTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/e5024d64e3fbbb8a9ba5520b2280c0e3ebc75174/src/treasuries/TimeConstrainedPaymentTreasury.sol)

**Inherits:**
[BasePaymentTreasury](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/BasePaymentTreasury.sol/abstract.BasePaymentTreasury.md), [TimestampChecker](/Users/mahabubalahi/Documents/ccp/ccprotocol-contracts-internal/docs/src/src/utils/TimestampChecker.sol/abstract.TimestampChecker.md)


## Functions
### constructor

Constructor for the TimeConstrainedPaymentTreasury contract.


```solidity
constructor() ;
```

### initialize


```solidity
function initialize(bytes32 _platformHash, address _infoAddress) external initializer;
```

### _checkTimeWithinRange

Internal function to check if current time is within the allowed range.


```solidity
function _checkTimeWithinRange() internal view;
```

### _checkTimeIsGreater

Internal function to check if current time is greater than launch time.


```solidity
function _checkTimeIsGreater() internal view;
```

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
    ICampaignPaymentTreasury.LineItem[] calldata lineItems,
    ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
) public override whenCampaignNotPaused whenCampaignNotCancelled;
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
|`lineItems`|`ICampaignPaymentTreasury.LineItem[]`|Array of line items associated with this payment.|
|`externalFees`|`ICampaignPaymentTreasury.ExternalFees[]`|Array of external fee metadata captured for this payment (informational only).|


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
    ICampaignPaymentTreasury.LineItem[][] calldata lineItemsArray,
    ICampaignPaymentTreasury.ExternalFees[][] calldata externalFeesArray
) public override whenCampaignNotPaused whenCampaignNotCancelled;
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
|`lineItemsArray`|`ICampaignPaymentTreasury.LineItem[][]`|An array of line item arrays, one for each payment.|
|`externalFeesArray`|`ICampaignPaymentTreasury.ExternalFees[][]`|An array of external fee metadata arrays, one for each payment (informational only).|


### processCryptoPayment

Allows a buyer to make a direct crypto payment for an item.

This function transfers tokens directly from the buyer's wallet and confirms the payment immediately.


```solidity
function processCryptoPayment(
    bytes32 paymentId,
    bytes32 itemId,
    address buyerAddress,
    address paymentToken,
    uint256 amount,
    ICampaignPaymentTreasury.LineItem[] calldata lineItems,
    ICampaignPaymentTreasury.ExternalFees[] calldata externalFees
) public override whenCampaignNotPaused whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`buyerAddress`|`address`|The address of the buyer making the payment.|
|`paymentToken`|`address`|The token to use for the payment.|
|`amount`|`uint256`|The amount to be paid for the item.|
|`lineItems`|`ICampaignPaymentTreasury.LineItem[]`|Array of line items associated with this payment.|
|`externalFees`|`ICampaignPaymentTreasury.ExternalFees[]`|Array of external fee metadata captured for this payment (informational only).|


### cancelPayment

Cancels an existing payment with the given payment ID.


```solidity
function cancelPayment(bytes32 paymentId) public override whenCampaignNotPaused whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to cancel.|


### confirmPayment

Confirms and finalizes the payment associated with the given payment ID.


```solidity
function confirmPayment(bytes32 paymentId, address buyerAddress)
    public
    override
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to confirm.|
|`buyerAddress`|`address`|Optional buyer address to mint NFT to. Pass address(0) to skip NFT minting.|


### confirmPaymentBatch

Confirms and finalizes multiple payments in a single transaction.


```solidity
function confirmPaymentBatch(bytes32[] calldata paymentIds, address[] calldata buyerAddresses)
    public
    override
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique payment identifiers to be confirmed.|
|`buyerAddresses`|`address[]`|Array of buyer addresses to mint NFTs to. Must match paymentIds length. Pass address(0) to skip NFT minting for specific payments.|


### claimRefund

Claims a refund for non-NFT payments (payments without minted NFTs).

Only callable by platform admin. Used for payments confirmed without a buyer address.


```solidity
function claimRefund(bytes32 paymentId, address refundAddress)
    public
    override
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must NOT have an NFT).|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


### claimRefund

Claims a refund for non-NFT payments (payments without minted NFTs).

Only callable by platform admin. Used for payments confirmed without a buyer address.


```solidity
function claimRefund(bytes32 paymentId) public override whenCampaignNotPaused whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must NOT have an NFT).|


### claimExpiredFunds

Allows platform admin to claim all remaining funds once the claim window has opened.


```solidity
function claimExpiredFunds() public override whenCampaignNotPaused whenCampaignNotCancelled;
```

### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public override whenCampaignNotPaused whenCampaignNotCancelled;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public override whenCampaignNotPaused whenCampaignNotCancelled;
```

### cancelTreasury

This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.


```solidity
function cancelTreasury(bytes32 message) public override;
```

### _checkSuccessCondition

Internal function to check the success condition for fee disbursement.


```solidity
function _checkSuccessCondition() internal view virtual override returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the success condition is met.|


## Errors
### TimeConstrainedPaymentTreasuryUnAuthorized
Emitted when an unauthorized action is attempted.


```solidity
error TimeConstrainedPaymentTreasuryUnAuthorized();
```

