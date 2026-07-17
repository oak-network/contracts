# PaymentTreasury
[Git Source](https://github.com/oak-network/contracts/blob/6c7f67f5ed14ef0f4f9444b95ac6770ae2af756a/src/treasuries/PaymentTreasury.sol)

**Inherits:**
[BasePaymentTreasury](/src/utils/BasePaymentTreasury.sol/abstract.BasePaymentTreasury.md)


## Functions
### constructor

Constructor for the PaymentTreasury contract.


```solidity
constructor() ;
```

### initialize


```solidity
function initialize(bytes32 _platformHash, address _infoAddress) external initializer;
```

### createPayment


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
) public override whenNotPaused whenNotCancelled;
```

### createPaymentBatch


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
) public override whenNotPaused whenNotCancelled;
```

### processCryptoPayment


```solidity
function processCryptoPayment(
    bytes32 paymentId,
    bytes32 itemId,
    address buyerAddress,
    address paymentToken,
    uint256 amount,
    ICampaignPaymentTreasury.LineItem[] calldata lineItems,
    ICampaignPaymentTreasury.ExternalFees[] calldata externalFees,
    PermitData calldata permitData
) public override whenNotPaused whenNotCancelled;
```

### cancelPayment

Cancels an existing payment with the given payment ID.


```solidity
function cancelPayment(bytes32 paymentId) public override whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to cancel.|


### confirmPayment

Confirms and finalizes the payment associated with the given payment ID.


```solidity
function confirmPayment(bytes32 paymentId, address buyerAddress) public override whenNotPaused whenNotCancelled;
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
    whenNotPaused
    whenNotCancelled;
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
function claimRefund(bytes32 paymentId, address refundAddress) public override whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must NOT have an NFT).|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


### claimRefund

Claims a refund for NFT payments (payments with minted NFTs).

Burns the NFT associated with the payment. Caller must have approved the treasury for the NFT.
Used for processCryptoPayment and confirmPayment (with buyer address) transactions.


```solidity
function claimRefund(bytes32 paymentId) public override whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment (must have an NFT).|


### claimExpiredFunds

Allows platform admin to claim all remaining funds once the claim window has opened.


```solidity
function claimExpiredFunds() public override whenNotPaused;
```

### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public override whenNotPaused;
```

### claimNonGoalLineItems

Allows platform admin to claim non-goal line items that are available for claiming.


```solidity
function claimNonGoalLineItems(address token) public override whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address to claim.|


### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public override whenNotPaused whenNotCancelled;
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
### PaymentTreasuryUnAuthorized
Emitted when an unauthorized action is attempted.


```solidity
error PaymentTreasuryUnAuthorized();
```

