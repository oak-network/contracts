# PaymentTreasury
[Git Source](https://github.com/ccprotocol/ccprotocol-contracts-internal/blob/08a57a0930f80d6f45ee44fa43ce6ad3e6c3c5c5/src/treasuries/PaymentTreasury.sol)

**Inherits:**
[BasePaymentTreasury](/src/utils/BasePaymentTreasury.sol/abstract.BasePaymentTreasury.md)


## State Variables
### s_name

```solidity
string private s_name;
```


### s_symbol

```solidity
string private s_symbol;
```


## Functions
### constructor

*Constructor for the PaymentTreasury contract.*


```solidity
constructor();
```

### initialize


```solidity
function initialize(bytes32 _platformHash, address _infoAddress, string calldata _name, string calldata _symbol)
    external
    initializer;
```

### name


```solidity
function name() public view returns (string memory);
```

### symbol


```solidity
function symbol() public view returns (string memory);
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
    uint256 expiration
) public override whenNotPaused whenNotCancelled;
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
) public override whenNotPaused whenNotCancelled;
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
function cancelPayment(bytes32 paymentId) public override whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to cancel.|


### confirmPayment

Confirms and finalizes the payment associated with the given payment ID.


```solidity
function confirmPayment(bytes32 paymentId) public override whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the payment to confirm.|


### confirmPaymentBatch

Confirms and finalizes multiple payments in a single transaction.


```solidity
function confirmPaymentBatch(bytes32[] calldata paymentIds) public override whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentIds`|`bytes32[]`|An array of unique payment identifiers to be confirmed.|


### claimRefund

Claims a refund for a specific payment ID.


```solidity
function claimRefund(bytes32 paymentId, address refundAddress) public override whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|
|`refundAddress`|`address`|The address where the refunded amount should be sent.|


### claimRefund

Claims a refund for a specific payment ID.


```solidity
function claimRefund(bytes32 paymentId) public override whenNotPaused whenNotCancelled;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paymentId`|`bytes32`|The unique identifier of the refundable payment.|


### disburseFees

Disburses fees collected by the treasury.


```solidity
function disburseFees() public override whenNotPaused whenNotCancelled;
```

### withdraw

Withdraws funds from the treasury.


```solidity
function withdraw() public override whenNotPaused whenNotCancelled;
```

### cancelTreasury

*This function is overridden to allow the platform admin and the campaign owner to cancel a treasury.*


```solidity
function cancelTreasury(bytes32 message) public override;
```

### _checkSuccessCondition

*Internal function to check the success condition for fee disbursement.*


```solidity
function _checkSuccessCondition() internal view virtual override returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the success condition is met.|


## Errors
### PaymentTreasuryUnAuthorized
*Emitted when an unauthorized action is attempted.*


```solidity
error PaymentTreasuryUnAuthorized();
```

