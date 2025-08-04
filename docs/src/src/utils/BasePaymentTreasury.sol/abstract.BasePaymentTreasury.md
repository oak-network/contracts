# BasePaymentTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/4076c45194ab23360a65e56402b026ef44f70a42/src/utils/BasePaymentTreasury.sol)

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


### PLATFORM_HASH

```solidity
bytes32 internal PLATFORM_HASH;
```


### PLATFORM_FEE_PERCENT

```solidity
uint256 internal PLATFORM_FEE_PERCENT;
```


### TOKEN

```solidity
IERC20 internal TOKEN;
```


### s_feesDisbursed

```solidity
bool internal s_feesDisbursed;
```


### s_payment

```solidity
mapping(bytes32 => PaymentInfo) internal s_payment;
```


### s_pendingPaymentAmount

```solidity
uint256 internal s_pendingPaymentAmount;
```


### s_confirmedPaymentAmount

```solidity
uint256 internal s_confirmedPaymentAmount;
```


### s_availableConfirmedPaymentAmount

```solidity
uint256 internal s_availableConfirmedPaymentAmount;
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


### createPayment

Creates a new payment entry with the specified details.


```solidity
function createPayment(bytes32 paymentId, address buyerAddress, bytes32 itemId, uint256 amount, uint256 expiration)
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
|`paymentId`|`bytes32`|A unique identifier for the payment.|
|`buyerAddress`|`address`|The address of the buyer initiating the payment.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`amount`|`uint256`|The amount to be paid for the item.|
|`expiration`|`uint256`|The timestamp after which the payment expires.|


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


```solidity
function claimRefund(bytes32 paymentId, address refundAddress)
    public
    virtual
    override
    onlyPlatformAdmin(PLATFORM_HASH)
    whenCampaignNotPaused
    whenCampaignNotCancelled;
```

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
If the campaign is paused, it reverts with TreasuryCampaignInfoIsPaused error.*


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
- The payment has already expired.*


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
    bytes32 indexed paymentId, address indexed buyerAddress, bytes32 indexed itemId, uint256 amount, uint256 expiration
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment.|
|`buyerAddress`|`address`|The address of the buyer who initiated the payment.|
|`itemId`|`bytes32`|The identifier of the item being purchased.|
|`amount`|`uint256`|The amount to be paid for the item.|
|`expiration`|`uint256`|The timestamp after which the payment expires.|

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
event FeesDisbursed(uint256 protocolShare, uint256 platformShare);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolShare`|`uint256`|The amount of fees sent to the protocol.|
|`platformShare`|`uint256`|The amount of fees sent to the platform.|

### WithdrawalSuccessful
Emitted when a withdrawal is successful.


```solidity
event WithdrawalSuccessful(address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient of the withdrawal.|
|`amount`|`uint256`|The amount withdrawn.|

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
*Throws an error indicating that the payment id is already exist.*


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
*Throws an error indicating that the payment id is not exist.*


```solidity
error PaymentTreasuryPaymentNotExist(bytes32 paymentId);
```

### PaymentTreasuryCampaignInfoIsPaused
*Throws an error indicating that the campaign is paused.*


```solidity
error PaymentTreasuryCampaignInfoIsPaused();
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

## Structs
### PaymentInfo

```solidity
struct PaymentInfo {
    address buyerAddress;
    bytes32 itemId;
    uint256 amount;
    uint256 expiration;
    bool isConfirmed;
}
```

