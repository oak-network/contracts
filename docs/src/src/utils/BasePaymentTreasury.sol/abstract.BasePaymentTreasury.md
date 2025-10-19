# BasePaymentTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/utils/BasePaymentTreasury.sol)

**Inherits:**
Initializable, [ICampaignPaymentTreasury](/src/interfaces/ICampaignPaymentTreasury.sol/interface.ICampaignPaymentTreasury.md), [CampaignAccessChecker](/src/utils/CampaignAccessChecker.sol/abstract.CampaignAccessChecker.md), [PausableCancellable](/src/utils/PausableCancellable.sol/abstract.PausableCancellable.md)


## State Variables
### ZERO_BYTES

```solidity
bytes32 internal constant ZERO_BYTES = 0x0000000000000000000000000000000000000000000000000000000000000000;
```


### PERCENT_DIVIDER

```solidity
uint256 internal constant PERCENT_DIVIDER = 10000;
```


### STANDARD_DECIMALS

```solidity
uint256 internal constant STANDARD_DECIMALS = 18;
```


### PLATFORM_HASH

```solidity
bytes32 internal PLATFORM_HASH;
```


### PLATFORM_FEE_PERCENT

```solidity
uint256 internal PLATFORM_FEE_PERCENT;
```


### s_paymentIdToToken

```solidity
mapping(bytes32 => address) internal s_paymentIdToToken;
```


### s_platformFeePerToken

```solidity
mapping(address => uint256) internal s_platformFeePerToken;
```


### s_protocolFeePerToken

```solidity
mapping(address => uint256) internal s_protocolFeePerToken;
```


### s_payment

```solidity
mapping(bytes32 => PaymentInfo) internal s_payment;
```


### s_pendingPaymentPerToken

```solidity
mapping(address => uint256) internal s_pendingPaymentPerToken;
```


### s_confirmedPaymentPerToken

```solidity
mapping(address => uint256) internal s_confirmedPaymentPerToken;
```


### s_availableConfirmedPerToken

```solidity
mapping(address => uint256) internal s_availableConfirmedPerToken;
```


## Functions
### __BaseContract_init


```solidity
function __BaseContract_init(bytes32 platformHash, address infoAddress) internal;
```

### whenCampaignNotPaused

*Modifier that checks if the campaign is not paused.*


```solidity
modifier whenCampaignNotPaused();
```

### whenCampaignNotCancelled


```solidity
modifier whenCampaignNotCancelled();
```

### onlyBuyerOrPlatformAdmin

Ensures that the caller is either the payment's buyer or the platform admin.


```solidity
modifier onlyBuyerOrPlatformAdmin(bytes32 paymentId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to validate access for.|


### getplatformHash

Retrieves the platform identifier associated with the treasury.


```solidity
function getplatformHash() external view override returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The platform identifier as a bytes32 value.|


### getplatformFeePercent

Retrieves the platform fee percentage for the treasury.


```solidity
function getplatformFeePercent() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The platform fee percentage as a uint256 value.|


### getRaisedAmount

Retrieves the total raised amount in the treasury.


```solidity
function getRaisedAmount() public view virtual override returns (uint256);
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


### _normalizeAmount

*Normalizes token amounts to 18 decimals for consistent comparisons.*


```solidity
function _normalizeAmount(address token, uint256 amount) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token address.|
|`amount`|`uint256`|The amount to normalize.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The normalized amount (scaled to 18 decimals).|


### createPayment

Creates a new payment entry with the specified details.


```solidity
function createPayment(
    bytes32 paymentId,
    bytes32 buyerId,
    bytes32 itemId,
    address paymentToken,
    uint256 amount,
    uint256 expiration
) public virtual override onlyPlatformAdmin(PLATFORM_HASH) whenCampaignNotPaused whenCampaignNotCancelled;
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


### processCryptoPayment

Allows a buyer to make a direct crypto payment for an item.

*This function transfers tokens directly from the buyer's wallet and confirms the payment immediately.*


```solidity
function processCryptoPayment(
    bytes32 paymentId,
    bytes32 itemId,
    address buyerAddress,
    address paymentToken,
    uint256 amount
) public virtual override whenCampaignNotPaused whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`buyerAddress`|`address`|The address of the buyer making the payment.|
|`paymentToken`|`address`|The token to use for the payment.|
|`amount`|`uint256`|The amount to be paid for the item.|


### cancelPayment

Cancels an existing payment with the given payment ID.


```solidity
function cancelPayment(bytes32 paymentId)
    public
    virtual
    override
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to cancel.|


### confirmPayment

Confirms and finalizes the payment associated with the given payment ID.


```solidity
function confirmPayment(bytes32 paymentId)
    public
    virtual
    override
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to confirm.|


### confirmPaymentBatch

Confirms and finalizes multiple payments in a single transaction.


```solidity
function confirmPaymentBatch(bytes32[] calldata paymentIds)
    public
    virtual
    override
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique payment identifiers to be confirmed.|


### claimRefund

Claims a refund for a specific payment ID.


```solidity
function claimRefund(bytes32 paymentId, address refundAddress)
    public
    virtual
    override
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


### claimRefund

Claims a refund for a specific payment ID.


```solidity
function claimRefund(bytes32 paymentId)
    public
    virtual
    override
    onlyBuyerOrPlatformAdmin(paymentId)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|


### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public virtual override whenCampaignNotPaused whenCampaignNotCancelled;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public virtual override whenCampaignNotPaused whenCampaignNotCancelled;
```

### pauseTreasury

*External function to pause the campaign.*


```solidity
function pauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### unpauseTreasury

*External function to unpause the campaign.*


```solidity
function unpauseTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### cancelTreasury

*External function to cancel the campaign.*


```solidity
function cancelTreasury(bytes32 message) public virtual onlyPlatformAdmin(PLATFORM_HASH);
```

### _revertIfCampaignPaused

*Internal function to check if the campaign is paused.
If the campaign is paused, it reverts with PaymentTreasuryCampaignInfoIsPaused error.*


```solidity
function _revertIfCampaignPaused() internal view;
```

### _revertIfCampaignCancelled


```solidity
function _revertIfCampaignCancelled() internal view;
```

### _validatePaymentForAction

*Validates the given payment ID to ensure it is eligible for further action.
Reverts if:
- The payment does not exist.
- The payment has already been confirmed.
- The payment has already expired.
- The payment is a crypto payment*


```solidity
function _validatePaymentForAction(bytes32 paymentId) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to validate.|


### _checkSuccessCondition

*Internal function to check the success condition for fee disbursement.*


```solidity
function _checkSuccessCondition() internal view virtual returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the success condition is met.|


## Events
### PaymentCreated
*Emitted when a new payment is created.*


```solidity
event PaymentCreated(
    address buyerAddress,
    bytes32 indexed paymentId,
    bytes32 buyerId,
    bytes32 indexed itemId,
    address indexed paymentToken,
    uint256 amount,
    uint256 expiration,
    bool isCryptoPayment
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`buyerAddress`|`address`|The address of the buyer making the payment.|
|`paymentId`|`bytes32`|The unique identifier of the payment.|
|`buyerId`|`bytes32`|The id of the buyer.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`paymentToken`|`address`|The token used for the payment.|
|`amount`|`uint256`|The amount to be paid for the item (in token's native decimals).|
|`expiration`|`uint256`|The timestamp after which the payment expires.|
|`isCryptoPayment`|`bool`|Boolean indicating whether the payment is made using direct crypto payment.|

### PaymentCancelled
*Emitted when a payment is cancelled and removed from the treasury.*


```solidity
event PaymentCancelled(bytes32 indexed paymentId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the cancelled payment.|

### PaymentConfirmed
*Emitted when a payment is confirmed.*


```solidity
event PaymentConfirmed(bytes32 indexed paymentId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the cancelled payment.|

### PaymentBatchConfirmed
*Emitted when multiple payments are confirmed in a single batch operation.*


```solidity
event PaymentBatchConfirmed(bytes32[] paymentIds);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique identifiers for the confirmed payments.|

### FeesDisbursed
Emitted when fees are successfully disbursed.


```solidity
event FeesDisbursed(address indexed token, uint256 protocolShare, uint256 platformShare);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token in which fees were disbursed.|
|`protocolShare`|`uint256`|The amount of fees sent to the protocol.|
|`platformShare`|`uint256`|The amount of fees sent to the platform.|

### WithdrawalWithFeeSuccessful
*Emitted when a withdrawal is successfully processed along with the applied fee.*


```solidity
event WithdrawalWithFeeSuccessful(address indexed token, address indexed to, uint256 amount, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token that was withdrawn.|
|`to`|`address`|The recipient address receiving the funds.|
|`amount`|`uint256`|The total amount withdrawn (excluding fee).|
|`fee`|`uint256`|The fee amount deducted from the withdrawal.|

### RefundClaimed
*Emitted when a refund is claimed.*


```solidity
event RefundClaimed(bytes32 indexed paymentId, uint256 refundAmount, address indexed claimer);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the cancelled payment.|
|`refundAmount`|`uint256`|The refund amount claimed.|
|`claimer`|`address`|The address of the claimer.|

## Errors
### PaymentTreasuryInvalidInput
*Reverts when one or more provided inputs to the payment treasury are invalid.*


```solidity
error PaymentTreasuryInvalidInput();
```

### PaymentTreasuryPaymentAlreadyExist
*Throws an error indicating that the payment id already exists.*


```solidity
error PaymentTreasuryPaymentAlreadyExist(bytes32 paymentId);
```

### PaymentTreasuryPaymentAlreadyConfirmed
*Throws an error indicating that the payment id is already confirmed.*


```solidity
error PaymentTreasuryPaymentAlreadyConfirmed(bytes32 paymentId);
```

### PaymentTreasuryPaymentAlreadyExpired
*Throws an error indicating that the payment id is already expired.*


```solidity
error PaymentTreasuryPaymentAlreadyExpired(bytes32 paymentId);
```

### PaymentTreasuryPaymentNotExist
*Throws an error indicating that the payment id does not exist.*


```solidity
error PaymentTreasuryPaymentNotExist(bytes32 paymentId);
```

### PaymentTreasuryCampaignInfoIsPaused
*Throws an error indicating that the campaign is paused.*


```solidity
error PaymentTreasuryCampaignInfoIsPaused();
```

### PaymentTreasuryTokenNotAccepted
*Emitted when a token is not accepted for the campaign.*


```solidity
error PaymentTreasuryTokenNotAccepted(address token);
```

### PaymentTreasurySuccessConditionNotFulfilled
*Throws an error indicating that the success condition was not fulfilled.*


```solidity
error PaymentTreasurySuccessConditionNotFulfilled();
```

### PaymentTreasuryFeeNotDisbursed
*Throws an error indicating that fees have not been disbursed.*


```solidity
error PaymentTreasuryFeeNotDisbursed();
```

### PaymentTreasuryPaymentNotConfirmed
*Throws an error indicating that the payment id is not confirmed.*


```solidity
error PaymentTreasuryPaymentNotConfirmed(bytes32 paymentId);
```

### PaymentTreasuryPaymentNotClaimable
*Emitted when claiming an unclaimable refund.*


```solidity
error PaymentTreasuryPaymentNotClaimable(bytes32 paymentId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|

### PaymentTreasuryAlreadyWithdrawn
*Emitted when an attempt is made to withdraw funds from the treasury but the payment has already been withdrawn.*


```solidity
error PaymentTreasuryAlreadyWithdrawn();
```

### PaymentTreasuryCryptoPayment
*This error is thrown when an operation is attempted on a crypto payment that is only valid for non-crypto payments.*


```solidity
error PaymentTreasuryCryptoPayment(bytes32 paymentId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment that caused the error.|

### PaymentTreasuryInsufficientFundsForFee
Emitted when the fee exceeds the requested withdrawal amount.


```solidity
error PaymentTreasuryInsufficientFundsForFee(uint256 withdrawalAmount, uint256 fee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawalAmount`|`uint256`|The amount requested for withdrawal.|
|`fee`|`uint256`|The calculated fee, which is greater than the withdrawal amount.|

### PaymentTreasuryInsufficientBalance
*Emitted when there are insufficient unallocated tokens for a payment confirmation.*


```solidity
error PaymentTreasuryInsufficientBalance(uint256 required, uint256 available);
```

## Structs
### PaymentInfo
*Stores information about a payment in the treasury.*


```solidity
struct PaymentInfo {
    address buyerAddress;
    bytes32 buyerId;
    bytes32 itemId;
    uint256 amount;
    uint256 expiration;
    bool isConfirmed;
    bool isCryptoPayment;
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

